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


/// @title An instantiator of compute
pragma solidity ^0.5.0;

import "./Decorated.sol";
import "./ComputeInterface.sol";
import "./VGInterface.sol";


contract ComputeInstantiator is ComputeInterface, Decorated {
    // after instantiation, the claimer will submit the final hash
    // then the challenger can either accept of challenge.
    // in the latter case a verification game will be instantiated
    // to resolve the dispute.

    VGInterface private vg;

    // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
    struct ComputeCtx {
        address challenger;
        address claimer;
        uint256 roundDuration; // time interval to interact with this contract
        uint256 timeOfLastMove; // last time someone made a move with deadline
        address machine; // machine which will run the challenge
        bytes32 initialHash;
        uint256 finalTime;
        bytes32 claimedFinalHash;
        uint256 vgInstance; // instance of verification game in case of dispute
        state currentState;
    }

    mapping(uint256 => ComputeCtx) internal instance;

    // These are the possible states and transitions of the contract.

    // +---+
    // |   |
    // +---+
    //   |
    //   | instantiate
    //   v
    // +--------------+ claimVictoryByTime +-----------------------+
    // | WaitingClaim |------------------->| ClaimerMisseddeadline |
    // +--------------+                    +-----------------------+
    //   |
    //   | submitClaim
    //   v
    // +---------------------+  confirm    +-----------------+
    // | WaitingConfirmation |------------>| ConsensusResult |
    // +---------------------+ or deadline +-----------------+
    //   |
    //   | challenge
    //   v
    // +------------------+ winByVG        +---------------+
    // | WaitingChallenge |--------------->| ChallengerWon |
    // +------------------+                +---------------+
    //   |
    //   |
    //   |                  winByVG        +------------+
    //   +-------------------------------->| ClaimerWon |
    //                                     +------------+
    //

    event ComputeCreated(
        uint256 _index,
        address _challenger,
        address _claimer,
        uint256 _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        uint256 _finalTime
    );
    event ClaimSubmitted(uint256 _index, bytes32 _claimedFinalHash);
    event ResultConfirmed(uint256 _index);
    event ChallengeStarted(uint256 _index);
    event ComputeFinished(uint256 _index, uint8 _state);

    constructor(address _vgInstantiatorAddress) public {
        vg = VGInterface(_vgInstantiatorAddress);
    }

    function instantiate(
        address _challenger,
        address _claimer,
        uint256 _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        uint256 _finalTime) public returns (uint256)
    {
        require(_challenger != _claimer, "Challenger and Claimer need to differ");
        ComputeCtx storage currentInstance = instance[currentIndex];
        currentInstance.challenger = _challenger;
        currentInstance.claimer = _claimer;
        currentInstance.roundDuration = _roundDuration;
        currentInstance.machine = _machineAddress;
        currentInstance.initialHash = _initialHash;
        currentInstance.finalTime = _finalTime;
        currentInstance.timeOfLastMove = now;

        emit ComputeCreated(
            currentIndex,
            _challenger,
            _claimer,
            _roundDuration,
            _machineAddress,
            _initialHash,
            _finalTime);

        active[currentIndex] = true;
        return currentIndex++;
    }

    function submitClaim(uint256 _index, bytes32 _claimedFinalHash) public
        onlyInstantiated(_index)
        onlyBy(instance[_index].claimer)
        increasesNonce(_index)
    {
        require(instance[_index].currentState == state.WaitingClaim, "State should be WaitingClaim");
        instance[_index].claimedFinalHash = _claimedFinalHash;
        instance[_index].currentState = state.WaitingConfirmation;

        emit ClaimSubmitted(_index, _claimedFinalHash);
    }

    function confirm(uint256 _index) public
        onlyInstantiated(_index)
        onlyBy(instance[_index].challenger)
        increasesNonce(_index)
    {
        require(instance[_index].currentState == state.WaitingConfirmation, "State should be WaitingConfirmation");
        instance[_index].currentState = state.ConsensusResult;
        clearInstance(_index);
        emit ResultConfirmed(_index);
    }

    function challenge(uint256 _index) public
        onlyInstantiated(_index)
        onlyBy(instance[_index].challenger)
        increasesNonce(_index)
    {
        require(instance[_index].currentState == state.WaitingConfirmation, "State should be WaitingConfirmation");
        instance[_index].vgInstance = vg.instantiate(
            instance[_index].challenger,
            instance[_index].claimer,
            instance[_index].roundDuration,
            instance[_index].machine,
            instance[_index].initialHash,
            instance[_index].claimedFinalHash,
            instance[_index].finalTime);
        instance[_index].currentState = state.WaitingChallenge;

        emit ChallengeStarted(_index);
    }

  /// @notice In case one of the parties wins the verification game,
  /// then he or she can call this function to claim victory in
  /// this contract as well.
    function winByVG(uint256 _index) public
        onlyInstantiated(_index)
        increasesNonce(_index)
    {
        require(instance[_index].currentState == state.WaitingChallenge, "State is not WaitingChallenge, cannot winByVG");
        uint256 vgIndex = instance[_index].vgInstance;

        if (vg.stateIsFinishedChallengerWon(vgIndex)) {
            challengerWins(_index);
            return;
        }

        if (vg.stateIsFinishedClaimerWon(vgIndex)) {
            claimerWins(_index);
            return;
        }
        require(false, "State of VG is not final");
    }

    /// @notice Claim victory for opponent timeout.
    function claimVictoryByTime(uint256 _index) public
        onlyInstantiated(_index)
        onlyAfter(instance[_index].timeOfLastMove + instance[_index].roundDuration)
        increasesNonce(_index)
    {
        if ((msg.sender == instance[_index].challenger) && (instance[_index].currentState == state.WaitingClaim)) {
            instance[_index].currentState = state.ClaimerMissedDeadline;
            deactivate(_index);
            emit ComputeFinished(_index, uint8(instance[_index].currentState));
            return;
        }
        if ((msg.sender == instance[_index].claimer) && (instance[_index].currentState == state.WaitingConfirmation)) {
            instance[_index].currentState = state.ConsensusResult;
            deactivate(_index);
            emit ComputeFinished(_index, uint8(instance[_index].currentState));
            return;
        }
        revert("Fail to ClaimVictoryByTime in current condition");
    }

    function isConcerned(uint256 _index, address _user) public view returns (bool) {
        return ((instance[_index].challenger == _user) || (instance[_index].claimer == _user));
    }

    function getSubInstances(uint256 _index)
        public view returns (address[] memory _addresses,
                            uint256[] memory _indices)
    {
        address[] memory a;
        uint256[] memory i;
        if (instance[_index].currentState == state.WaitingChallenge) {
            a = new address[](1);
            i = new uint256[](1);
            a[0] = address(vg);
            i[0] = instance[_index].vgInstance;
            return (a, i);
        }
        a = new address[](0);
        i = new uint256[](0);
        return (a, i);
    }

    function getState(uint256 _index) public view returns
        ( address _challenger,
        address _claimer,
        uint256 _roundDuration,
        uint256 _timeOfLastMove,
        address _machine,
        bytes32 _initialHash,
        uint256 _finalTime,
        bytes32 _claimedFinalHash,
        bytes32 _currentState
        )
    {
        ComputeCtx memory i = instance[_index];

        // we have to duplicate the code for getCurrentState because of
        // "stack too deep"
        bytes32 currentState;
        if (instance[_index].currentState == state.WaitingClaim) {
            currentState = "WaitingClaim";
        }
        if (instance[_index].currentState == state.WaitingConfirmation) {
            currentState = "WaitingConfirmation";
        }
        if (instance[_index].currentState == state.ClaimerMissedDeadline) {
            currentState = "ClaimerMissedDeadline";
        }
        if (instance[_index].currentState == state.WaitingChallenge) {
            currentState = "WaitingChallenge";
        }
        if (instance[_index].currentState == state.ChallengerWon) {
            currentState = "ChallengerWon";
        }
        if (instance[_index].currentState == state.ClaimerWon) {
            currentState = "ClaimerWon";
        }
        if (instance[_index].currentState == state.ConsensusResult) {
            currentState = "ConsensusResult";
        }

        return (
            i.challenger,
            i.claimer,
            i.roundDuration,
            i.timeOfLastMove,
            i.machine,
            i.initialHash,
            i.finalTime,
            i.claimedFinalHash,
            currentState
        );
    }

    function getCurrentState(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bytes32)
    {
        if (instance[_index].currentState == state.WaitingClaim) {
            return "WaitingClaim";
        }
        if (instance[_index].currentState == state.WaitingConfirmation) {
            return "WaitingConfirmation";
        }
        if (instance[_index].currentState == state.ClaimerMissedDeadline) {
            return "ClaimerMissedDeadline";
        }
        if (instance[_index].currentState == state.WaitingChallenge) {
            return "WaitingChallenge";
        }
        if (instance[_index].currentState == state.ChallengerWon) {
            return "ChallengerWon";
        }
        if (instance[_index].currentState == state.ClaimerWon) {
            return "ClaimerWon";
        }
        if (instance[_index].currentState == state.ConsensusResult) {
            return "ConsensusResult";
        }
        require(false, "Unrecognized state");
    }

    // remove these functions and change tests accordingly
    function stateIsWaitingClaim(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.WaitingClaim; }

    function stateIsWaitingConfirmation(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.WaitingConfirmation; }

    function stateIsClaimerMissedDeadline(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.ClaimerMissedDeadline; }

    function stateIsWaitingChallange(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.WaitingChallenge; }

    function stateIsChallengerWon(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.ChallengerWon; }

    function stateIsClaimerWon(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.ClaimerWon; }

    function stateIsConsensusResult(uint256 _index) public view
        onlyInstantiated(_index)
        returns (bool)
    { return instance[_index].currentState == state.ConsensusResult; }

    function clearInstance(uint256 _index) internal {
        delete instance[_index].challenger;
        delete instance[_index].claimer;
        delete instance[_index].roundDuration;
        delete instance[_index].timeOfLastMove;
        delete instance[_index].machine;
        delete instance[_index].initialHash;
        delete instance[_index].finalTime;
        // !!!!!!!!! should call clear in vgInstance !!!!!!!!!
        delete instance[_index].vgInstance;
        deactivate(_index);
    }

    function challengerWins(uint256 _index) private
        onlyInstantiated(_index)
    {
        clearInstance(_index);
        instance[_index].currentState = state.ChallengerWon;
        emit ComputeFinished(_index, uint8(instance[_index].currentState));
    }

    function claimerWins(uint256 _index) private
        onlyInstantiated(_index)
    {
        clearInstance(_index);
        instance[_index].currentState = state.ClaimerWon;
        emit ComputeFinished(_index, uint8(instance[_index].currentState));
    }
}
