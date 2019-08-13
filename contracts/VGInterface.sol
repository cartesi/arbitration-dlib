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


// @title Verification game instantiator
pragma solidity ^0.5.0;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";


contract VGInterface is Instantiator {
    enum state {
        WaitPartition,
        WaitMemoryProveValues,
        FinishedClaimerWon,
        FinishedChallengerWon
    }

    function instantiate(
        address _challenger,
        address _claimer,
        uint _roundDuration,
        address _machineAddress,
        bytes32 _initialHash,
        bytes32 _claimerFinalHash,
        uint _finalTime) public returns (uint256);

    function getCurrentState(uint256 _index) public view returns (bytes32);
    function stateIsFinishedClaimerWon(uint256 _index) public view returns (bool);
    function stateIsFinishedChallengerWon(uint256 _index) public view returns (bool);
    function winByPartitionTimeout(uint256 _index) public;
    function startMachineRunChallenge(uint256 _index) public;
    function settleVerificationGame(uint256 _index) public;
    function claimVictoryByTime(uint256 _index) public;
    //function stateIsWaitPartition(uint256 _index) public view returns (bool);
    //function stateIsWaitMemoryProveValues(uint256 _index) public view
    //  returns (bool);
    function clearInstance(uint256 _index) internal;
    function challengerWins(uint256 _index) private;
    function claimerWins(uint256 _index) private;
}
