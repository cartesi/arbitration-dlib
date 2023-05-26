// Copyright (C) 2020 Cartesi Pte. Ltd.

// SPDX-License-Identifier: GPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.

// This program is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Note: This component currently has dependencies that are licensed under the GNU
// GPL, version 3, and so you should treat this component as a whole as being under
// the GPL version 3. But all Cartesi-written code in this component is licensed
// under the Apache License, version 2, or a compatible permissive license, and can
// be used independently under the Apache v2 license. After this component is
// rewritten, the entire component will be released under the Apache v2 license.

// @title Verification game instantiator
pragma solidity ^0.8.0;

import "@cartesi/util/contracts/DecoratedV2.sol";
import "@cartesi/util/contracts/InstantiatorImplV2.sol";
import "./VGInterface.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";

contract VGInstantiator is InstantiatorImplV2, DecoratedV2, VGInterface {
    //  using SafeMath for uint;

    PartitionInterface private partition;
    MMInterface private mm;

    struct VGCtx {
        address challenger; // the two parties involved in each instance
        address claimer;
        uint roundDuration; // time interval to interact with this contract
        MachineInterface machine; // the machine which will run the challenge
        bytes32 initialHash; // hash of machine memory that both aggree uppon
        bytes32 claimerFinalHash; // hash claimer commited for machine after running
        uint finalTime; // the time for which the machine should run
        uint timeOfLastMove; // last time someone made a move with deadline
        uint256 mmInstance; // the instance of the memory that was given to this game
        uint256 partitionInstance; // the partition instance given to this game
        uint divergenceTime; // the time in which the divergence happened
        bytes32 hashBeforeDivergence; // hash aggreed right before divergence
        bytes32 hashAfterDivergence; // hash in conflict right after divergence
        state currentState;
    }

    mapping(uint256 => VGCtx) private instance;

    // These are the possible states and transitions of the contract.
    //
    //               +---+
    //               |   |
    //               +---+
    //                 |
    //                 | instantiate
    //                 v
    //               +----------------+  winByPartitionTimeout
    //   +-----------| WaitPartition  |------------------------+
    //   |           +----------------+                        |
    //   |                         |                           |
    //   | winByPartitionTimeout   | startMachineRunChallenge  |
    //   |                         v                           |
    //   |           +-----------------------+                 |
    //   | +---------| WaitMemoryProveValues |---------------+ |
    //   | |         +-----------------------+               | |
    //   | |                                                 | |
    //   | |claimVictoryByDeadline   settleVerificationGame  | |
    //   v v                                                 v v
    // +--------------------+               +-----------------------+
    // | FinishedClaimerWon |               | FinishedChallengerWon |
    // +--------------------+               +-----------------------+
    //

    event VGCreated(
        uint256 _index,
        address _challenger,
        address _claimer,
        uint _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        bytes32 _claimerFinalHash,
        uint _finalTime,
        uint256 _partitionInstance
    );
    event PartitionDivergenceFound(uint256 _index, uint256 _mmInstance);
    event MemoryWriten(uint256 _index);
    event VGFinished(state _finalState);

    constructor(
        address _partitionInstantiatorAddress,
        address _mmInstantiatorAddress
    ) {
        partition = PartitionInterface(_partitionInstantiatorAddress);
        mm = MMInterface(_mmInstantiatorAddress);
    }

    /// @notice Instantiate a vg instance.
    /// @param _challenger address of the challenger.
    /// @param _claimer address of the claimer.
    /// @param _roundDuration duration of the round (security param)
    /// @param _machineAddress address of the machine that will run the instruction
    /// @param _initialHash hash in which both claimer and challenger agree on
    /// @param _claimerFinalHash final hash claimed by claimer
    /// @param _finalTime max cycle of the machine for that computation
    /// @return VG index.
    function instantiate(
        address _challenger,
        address _claimer,
        uint _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        bytes32 _claimerFinalHash,
        uint _finalTime
    ) public override returns (uint256) {
        require(_finalTime > 0, "Final time must be greater than zero");
        instance[currentIndex].challenger = _challenger;
        instance[currentIndex].claimer = _claimer;
        instance[currentIndex].roundDuration =
            _roundDuration *
            log2OverTwo(_finalTime) +
            4;
        instance[currentIndex].machine = MachineInterface(_machineAddress);
        instance[currentIndex].initialHash = _initialHash;
        instance[currentIndex].claimerFinalHash = _claimerFinalHash;
        instance[currentIndex].finalTime = _finalTime;
        instance[currentIndex].timeOfLastMove = block.timestamp;
        instance[currentIndex].partitionInstance = partition.instantiate(
            _challenger,
            _claimer,
            _initialHash,
            _claimerFinalHash,
            _finalTime,
            10,
            _roundDuration
        );
        instance[currentIndex].currentState = state.WaitPartition;
        emit VGCreated(
            currentIndex,
            _challenger,
            _claimer,
            _roundDuration * log2OverTwo(_finalTime) + 4,
            _machineAddress,
            _initialHash,
            _claimerFinalHash,
            _finalTime,
            instance[currentIndex].partitionInstance
        );

        active[currentIndex] = true;
        return (currentIndex++);
    }

    /// @notice In case one of the parties wins the partition challenge by
    /// timeout, then he or she can call this function to claim victory in
    /// the hireCPU contract as well.

    // TO-DO: should this stop existing? We can make claimVictory by timeout generic
    function winByPartitionTimeout(
        uint256 _index
    ) public override onlyInstantiated(_index) {
        require(
            instance[_index].currentState == state.WaitPartition,
            "State should be WaitPartition"
        );
        uint256 partitionIndex = instance[_index].partitionInstance;
        if (partition.stateIsChallengerWon(partitionIndex)) {
            challengerWins(_index);
            return;
        }
        if (partition.stateIsClaimerWon(partitionIndex)) {
            claimerWins(_index);
            return;
        }
        revert("Fail to WinByPartitionTimeout in current condition");
    }

    /// @notice After the partition challenge has lead to a divergence in the hash
    /// within one time step, anyone can start a mechine run challenge to decide
    /// whether the claimer was correct about that particular step transition.
    /// This function call solely instantiate a memory manager, so the
    /// provider must fill the appropriate addresses that will be read by the
    /// machine.
    function startMachineRunChallenge(
        uint256 _index
    ) public override onlyInstantiated(_index) increasesNonce(_index) {
        require(
            instance[_index].currentState == state.WaitPartition,
            "State should be WaitPartition"
        );
        require(
            partition.stateIsDivergenceFound(
                instance[_index].partitionInstance
            ),
            "Divergence should be found"
        );
        uint256 partitionIndex = instance[_index].partitionInstance;
        uint divergenceTime = partition.divergenceTime(partitionIndex);
        instance[_index].divergenceTime = divergenceTime;
        instance[_index].hashBeforeDivergence = partition.timeHash(
            partitionIndex,
            divergenceTime
        );
        instance[_index].hashAfterDivergence = partition.timeHash(
            partitionIndex,
            divergenceTime + 1
        );
        instance[_index].mmInstance = mm.instantiate(
            address(this),
            instance[_index].challenger,
            instance[_index].hashBeforeDivergence
        );
        // !!!!!!!!! should call clear in partitionInstance !!!!!!!!!
        delete instance[_index].partitionInstance;
        instance[_index].timeOfLastMove = block.timestamp;
        instance[_index].currentState = state.WaitMemoryProveValues;
        emit PartitionDivergenceFound(_index, instance[_index].mmInstance);
    }

    /// @notice After having filled the memory manager with the necessary data,
    /// the provider calls this function to instantiate the machine and perform
    /// one step on it. The machine will write to memory now. Later, the
    /// provider will be expected to update the memory hash accordingly.
    function settleVerificationGame(
        uint256 _index
    )
        public
        override
        onlyInstantiated(_index)
        onlyBy(instance[_index].challenger)
    {
        require(
            instance[_index].currentState == state.WaitMemoryProveValues,
            "State should be WaitMemoryProveValues"
        );
        uint256 mmIndex = instance[_index].mmInstance;
        require(
            mm.stateIsWaitingReplay(mmIndex),
            "State of MM should be WaitingReplay"
        );

        (
            uint64[] memory positions,
            bytes8[] memory values,
            bool[] memory wasRead
        ) = mm.getRWArrays(mmIndex);

        (uint8 exitCode, uint256 memoryAccesses) = instance[_index]
            .machine
            .step(positions, values, wasRead);

        mm.finishReplayPhase(mmIndex);

        require(
            mm.stateIsFinishedReplay(mmIndex),
            "State of MM should be FinishedReplay"
        );

        if (
            exitCode == 0 && // Step exits correctly
            memoryAccesses == positions.length && // Number of memory acceses matches
            mm.newHash(mmIndex) != instance[_index].hashAfterDivergence // proves challenger newHash diverge from claimer
        ) {
            challengerWins(_index);
        }
        claimerWins(_index);
    }

    /// @notice Claimer can claim victory if challenger has lost the deadline
    /// for some of the steps in the protocol.
    function claimVictoryByTime(
        uint256 _index
    )
        public
        override
        onlyInstantiated(_index)
        onlyBy(instance[_index].claimer)
    {
        // TO-DO: should we add onlyAfter as a function in solidity-utils lib?
        // This should be the onlyAfter modifier, but it cannot use functions:
        // DeclarationError: Function type can not be used in this context.
        // TO-DO: change the hardcode numbers
        require(
            block.timestamp >
                instance[_index].timeOfLastMove +
                    getMaxStateDuration(
                        instance[_index].currentState,
                        instance[_index].roundDuration,
                        40, // time to start machine
                        partition.getQuerySize(
                            instance[_index].partitionInstance
                        ),
                        instance[_index].finalTime, //maxCycle
                        500 // pico seconds to run insn
                    ),
            "Duration of WaitMemoryProveValues must be over"
        );

        require(
            instance[_index].currentState == state.WaitMemoryProveValues,
            "State should be WaitMemoryProveValues"
        );
        claimerWins(_index);
    }

    // state getters
    function getCurrentStateDeadline(
        uint _index
    ) public view onlyInstantiated(_index) returns (uint time) {
        VGCtx memory i = instance[_index];
        time =
            i.timeOfLastMove +
            getMaxStateDuration(
                _index,
                i.roundDuration,
                40 // time to start machine @DEV I want to use preprocessor constant for this, like:
                // #def TIMETOSTARTMACHINE 40
            );
    }

    function getState(
        uint256 _index,
        address
    )
        public
        view
        onlyInstantiated(_index)
        returns (
            address _challenger,
            address _claimer,
            MachineInterface _machine,
            bytes32 _initialHash,
            bytes32 _claimerFinalHash,
            bytes32 _hashBeforeDivergence,
            bytes32 _hashAfterDivergence,
            bytes32 _currentState,
            uint[] memory _uintValues
        )
    {
        VGCtx memory i = instance[_index];

        uint[] memory uintValues = new uint[](5);
        uintValues[0] = i.finalTime;
        uintValues[1] =
            i.timeOfLastMove +
            getMaxStateDuration(
                i.currentState,
                i.roundDuration,
                40, // time to start machine
                partition.getQuerySize(i.partitionInstance),
                i.finalTime, //maxCycle
                500 // pico seconds to run insn
            ); //deadline
        uintValues[2] = i.mmInstance;
        uintValues[3] = i.partitionInstance;
        uintValues[4] = i.divergenceTime;

        // we have to duplicate the code for getCurrentState because of
        // "stack too deep"
        bytes32 currentState;
        if (i.currentState == state.WaitPartition) {
            currentState = "WaitPartition";
        }
        if (i.currentState == state.WaitMemoryProveValues) {
            currentState = "WaitMemoryProveValues";
        }
        if (i.currentState == state.FinishedClaimerWon) {
            currentState = "FinishedClaimerWon";
        }
        if (i.currentState == state.FinishedChallengerWon) {
            currentState = "FinishedChallengerWon";
        }

        return (
            i.challenger,
            i.claimer,
            i.machine,
            i.initialHash,
            i.claimerFinalHash,
            i.hashBeforeDivergence,
            i.hashAfterDivergence,
            currentState,
            uintValues
        );
    }

    function isConcerned(
        uint256 _index,
        address _user
    ) public view override returns (bool) {
        return ((instance[_index].challenger == _user) ||
            (instance[_index].claimer == _user));
    }

    function getMaxStateDuration(
        uint256 _index,
        uint256 _roundDuration,
        uint256 _timeToStartMachine
    ) private view returns (uint256) {
        VGCtx memory i = instance[_index];
        // TODO: the 1 should probably be roundDuration
        if (instance[_index].currentState == state.WaitPartition) {
            return
                partition.getCurrentStateDeadline(i.partitionInstance) -
                i.timeOfLastMove;
        }
        if (instance[_index].currentState == state.WaitMemoryProveValues) {
            return
                mm.getCurrentStateDeadline(
                    i.mmInstance,
                    _roundDuration,
                    _timeToStartMachine
                );
        }

        if (
            instance[_index].currentState == state.FinishedClaimerWon ||
            instance[_index].currentState == state.FinishedChallengerWon
        ) {
            return 0; // final state
        }
        require(false, "Unrecognized state");
    }

    /// @notice Get the worst case scenario duration for a specific state
    /// @param _roundDuration security parameter, the max time an agent
    //          has to react and submit one simple transaction
    /// @param _timeToStartMachine time to build the machine for the first time
    /// @param _partitionSize size of partition, how many instructions the
    //          will run to reach the necessary hash
    /// @param _maxCycle is the maximum amount of steps a machine can perform
    //          before being forced into becoming halted
    //  @DEV I want to delete this..can we change the getMaxInstanceDuration interface safely??
    function getMaxStateDuration(
        state _state,
        uint256 _roundDuration,
        uint256 _timeToStartMachine,
        uint256 _partitionSize,
        uint256 _maxCycle,
        uint256 _picoSecondsToRunInsn
    ) private view returns (uint256) {
        // TODO: the 1 should probably be roundDuration
        if (_state == state.WaitPartition) {
            return
                partition.getMaxInstanceDuration(
                    _roundDuration,
                    _timeToStartMachine,
                    _partitionSize,
                    _maxCycle,
                    _picoSecondsToRunInsn
                );
        }
        if (_state == state.WaitMemoryProveValues) {
            return
                mm.getMaxInstanceDuration(_roundDuration, _timeToStartMachine);
        }

        if (
            _state == state.FinishedClaimerWon ||
            _state == state.FinishedChallengerWon
        ) {
            return 0; // final state
        }
        require(false, "Unrecognized state");
    }

    /// @notice Get the worst case scenario duration for a specific state
    /// @param _roundDuration security parameter, the max time an agent
    //          has to react and submit one simple transaction
    /// @param _maxCycle is the maximum amount of steps a machine can perform
    //          before being forced into becoming halted
    function getMaxInstanceDuration(
        uint256 _roundDuration,
        uint256 _timeToStartMachine,
        uint256 _partitionSize,
        uint256 _maxCycle,
        uint256 _picoSecondsToRunInsn
    ) public view override returns (uint256) {
        uint256 waitPartitionDuration = getMaxStateDuration(
            state.WaitPartition,
            _roundDuration,
            _timeToStartMachine,
            _partitionSize,
            _maxCycle,
            _picoSecondsToRunInsn
        );

        uint256 waitMemoryProveValues = getMaxStateDuration(
            state.WaitMemoryProveValues,
            _roundDuration,
            _timeToStartMachine,
            _partitionSize,
            _maxCycle,
            _picoSecondsToRunInsn
        );

        return waitPartitionDuration + waitMemoryProveValues;
    }

    function getSubInstances(
        uint256 _index,
        address
    )
        public
        view
        override
        returns (address[] memory _addresses, uint256[] memory _indices)
    {
        address[] memory a;
        uint256[] memory i;
        if (instance[_index].currentState == state.WaitPartition) {
            a = new address[](1);
            i = new uint256[](1);
            a[0] = address(partition);
            i[0] = instance[_index].partitionInstance;
            return (a, i);
        }
        if (instance[_index].currentState == state.WaitMemoryProveValues) {
            a = new address[](1);
            i = new uint256[](1);
            a[0] = address(mm);
            i[0] = instance[_index].mmInstance;
            return (a, i);
        }
        a = new address[](0);
        i = new uint256[](0);
        return (a, i);
    }

    function getCurrentState(
        uint256 _index
    ) public view override onlyInstantiated(_index) returns (bytes32) {
        if (instance[_index].currentState == state.WaitPartition) {
            return "WaitPartition";
        }
        if (instance[_index].currentState == state.WaitMemoryProveValues) {
            return "WaitMemoryProveValues";
        }
        if (instance[_index].currentState == state.FinishedClaimerWon) {
            return "FinishedClaimerWon";
        }
        if (instance[_index].currentState == state.FinishedChallengerWon) {
            return "FinishedChallengerWon";
        }
        require(false, "Unrecognized state");
    }

    // remove these functions and change tests accordingly
    /* function stateIsWaitPartition(uint256 _index) public view */
    /*   onlyInstantiated(_index) */
    /*   returns (bool) */
    /* { return instance[_index].currentState == state.WaitPartition; } */

    /* function stateIsWaitMemoryProveValues(uint256 _index) public view */
    /*   onlyInstantiated(_index) */
    /*   returns (bool) */
    /* { return instance[_index].currentState == state.WaitMemoryProveValues; } */

    function stateIsFinishedClaimerWon(
        uint256 _index
    ) public view override onlyInstantiated(_index) returns (bool) {
        return instance[_index].currentState == state.FinishedClaimerWon;
    }

    function stateIsFinishedChallengerWon(
        uint256 _index
    ) public view override onlyInstantiated(_index) returns (bool) {
        return instance[_index].currentState == state.FinishedChallengerWon;
    }

    function clearInstance(uint256 _index) internal onlyInstantiated(_index) {
        delete instance[_index].challenger;
        delete instance[_index].claimer;
        delete instance[_index].roundDuration;
        delete instance[_index].machine;
        delete instance[_index].initialHash;
        delete instance[_index].claimerFinalHash;
        delete instance[_index].finalTime;
        delete instance[_index].timeOfLastMove;
        // !!!!!!!!! should call clear in mmInstance !!!!!!!!!
        delete instance[_index].mmInstance;
        delete instance[_index].divergenceTime;
        delete instance[_index].hashBeforeDivergence;
        delete instance[_index].hashAfterDivergence;
        deactivate(_index);
    }

    function challengerWins(uint256 _index) private onlyInstantiated(_index) {
        clearInstance(_index);
        instance[_index].currentState = state.FinishedChallengerWon;
        emit VGFinished(instance[_index].currentState);
    }

    function claimerWins(uint256 _index) private onlyInstantiated(_index) {
        clearInstance(_index);
        instance[_index].currentState = state.FinishedClaimerWon;
        emit VGFinished(instance[_index].currentState);
    }

    function getPartitionQuerySize(
        uint256 _index
    ) public view override returns (uint256) {
        return partition.getQuerySize(instance[_index].partitionInstance);
    }

    function getPartitionGameIndex(
        uint256 _index
    ) public view override returns (uint256) {
        return
            partition.getPartitionGameIndex(instance[_index].partitionInstance);
    }

    //TODO: It is supposed to be log10 * C, because we're using a partition of 10
    function log2OverTwo(uint x) public pure returns (uint y) {
        uint leading = 256;

        while (x != 0) {
            x = x >> 1;
            leading--;
        }
        // plus one to do an approx ceiling
        return (255 - leading) / 2;
    }
}
