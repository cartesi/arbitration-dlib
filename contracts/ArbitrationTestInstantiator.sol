// Arbritration DLib is the combination of the on-chain protocol and off-chain
// protocol that work together to resolve any disputes that might occur during the
// execution of a Cartesi DApp.

// Copyright (C) 2019 Cartesi Pte. Ltd.

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


/// @title An instantiator of arbitration test
pragma solidity ^0.5.0;

import "./Decorated.sol";
import "./ArbitrationTestInterface.sol";
import "./ComputeInterface.sol";


contract ArbitrationTestInstantiator is ArbitrationTestInterface, Decorated {
    // after construction, the test is in the Idle state and can be changed to Waiting,
    // then an compute instance will be created, and everything being take care by compute
    // the state can be changed to Finished if compute is not active anymore

    ComputeInterface private compute;

    // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
    struct ArbitrationTestCtx {
        address challenger;
        address claimer;
        address machine; // machine which will run the challenge
        uint256 roundDuration;
        bytes32 initialHash;
        uint256 finalTime;
        uint256 computeInstance; // instance of verification game in case of dispute
        state currentState;
    }

    mapping(uint256 => ArbitrationTestCtx) internal instance;

    // These are the possible states and transitions of the contract.

    // +---+
    // |   |
    // +---+
    //   |
    //   | constructor
    //   v
    // +------+
    // | Idle |
    // +------+
    //   |
    //   | claimWaiting
    //   v
    // +---------+
    // | Waiting |
    // +---------+
    //   |
    //   | claimFinished
    //   v
    // +----------+
    // | Finished |
    // +----------+

    event ArbitrationTestCreated(
        uint256 _index,
        address _challenger,
        address _claimer,
        address _machineAddress
    );
    event ClaimSubmitted(uint256 _index, bytes32 _claimedFinalHash);
    event ResultConfirmed(uint256 _index);
    event ChallengeStarted(uint256 _index);
    event ArbitrationTestFinished(uint256 _index, uint8 _state);

    constructor(
        address _challenger,
        address _claimer,
        uint256 _roundDuration,
        address _machineAddress,
        address _computeInstantiatorAddress,
        bytes32 _initialHash,
        uint256 _finalTime) public {
        require(_challenger != _claimer, "Challenger and Claimer need to differ");
        currentIndex = 0;
        compute = ComputeInterface(_computeInstantiatorAddress);
        ArbitrationTestCtx storage currentInstance = instance[currentIndex];
        currentInstance.challenger = _challenger;
        currentInstance.claimer = _claimer;
        currentInstance.machine = _machineAddress;
        currentInstance.roundDuration = _roundDuration;
        currentInstance.initialHash = _initialHash;
        currentInstance.finalTime = _finalTime;
        currentInstance.currentState = state.Idle;

        emit ArbitrationTestCreated(
            currentIndex,
            _challenger,
            _claimer,
            _machineAddress);

        active[currentIndex] = true;
        currentIndex++;
    }

    /// @notice Claim Waiting for the arbitration test.
    function claimWaiting(uint256 _index) public
        onlyInstantiated(_index)
    {
        require(instance[_index].currentState == state.Idle, "The state should be Idle");
        if (msg.sender == instance[_index].claimer || msg.sender == instance[_index].challenger) {
            instance[_index].currentState = state.Waiting;
            instance[_index].computeInstance = compute.instantiate(
            instance[_index].challenger,
            instance[_index].claimer,
            instance[_index].roundDuration,
            instance[_index].machine,
            instance[_index].initialHash,
            instance[_index].finalTime);
            return;
        }
        revert("The caller is neither claimer nor challenger");
    }

    /// @notice Claim Finished for the arbitration test.
    function claimFinished(uint256 _index) public
        onlyInstantiated(_index)
    {
        require(instance[_index].currentState == state.Waiting, "The state should be Waiting");
        if (msg.sender == instance[_index].claimer || msg.sender == instance[_index].challenger) {
            bytes32 computeState = compute.getCurrentState(instance[_index].computeInstance);
            if (computeState == "ClaimerMissedDeadline" ||
                computeState == "ChallengerWon" ||
                computeState == "ClaimerWon" ||
                computeState == "ConsensusResult") {
                instance[_index].currentState = state.Finished;
                deactivate(_index);
                emit ArbitrationTestFinished(_index, uint8(instance[_index].currentState));
            } else {
                revert("The subinstance compute is still active");
            }
            return;
        }
        revert("The caller is neither claimer nor challenger");
    }

    function isConcerned(uint256 _index, address _user) public view returns (bool) {
        return ((instance[_index].challenger == _user) || (instance[_index].claimer == _user));
    }

    function getSubInstances(uint256 _index, address)
        public view returns (address[] memory _addresses,
                            uint256[] memory _indices)
    {
        address[] memory a;
        uint256[] memory i;
        if (instance[_index].currentState == state.Waiting) {
            a = new address[](1);
            i = new uint256[](1);
            a[0] = address(compute);
            i[0] = instance[_index].computeInstance;
            return (a, i);
        }
        a = new address[](0);
        i = new uint256[](0);
        return (a, i);
    }

    function getState(uint256 _index, address) public view returns
        ( address _challenger,
        address _claimer,
        address _machine,
        uint256 _roundDuration,
        bytes32 _initialHash,
        uint256 _finalTime,
        bytes32 _currentState
        )
    {
        ArbitrationTestCtx memory i = instance[_index];

        // we have to duplicate the code for getCurrentState because of
        // "stack too deep"
        bytes32 currentState;
        if (instance[_index].currentState == state.Idle) {
            currentState = "Idle";
        }
        if (instance[_index].currentState == state.Waiting) {
            currentState = "Waiting";
        }
        if (instance[_index].currentState == state.Finished) {
            currentState = "Finished";
        }

        return (
            i.challenger,
            i.claimer,
            i.machine,
            i.roundDuration,
            i.initialHash,
            i.finalTime,
            currentState
        );
    }

    function getCurrentState(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bytes32)
    {
        if (instance[_index].currentState == state.Waiting) {
            return "Idle";
        }
        if (instance[_index].currentState == state.Waiting) {
            return "Waiting";
        }
        if (instance[_index].currentState == state.Finished) {
            return "Finished";
        }
        require(false, "Unrecognized state");
    }

    // remove these functions and change tests accordingly
    function stateIsWaiting(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.Waiting; }

    function stateIsFinished(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.Finished; }

    function clearInstance(uint256 _index) internal {
        delete instance[_index].challenger;
        delete instance[_index].claimer;
        delete instance[_index].machine;
        // !!!!!!!!! should call clear in computeInstance !!!!!!!!!
        delete instance[_index].computeInstance;
        deactivate(_index);
    }
}
