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


/// @title Abstract interface for partition instantiator
pragma solidity ^0.5.0;

import "./Instantiator.sol";


contract PartitionInterface is Instantiator {
    enum state {
        WaitingQuery,
        WaitingHashes,
        ChallengerWon,
        ClaimerWon,
        DivergenceFound
    }

    function getCurrentState(uint256 _index) public view returns (bytes32);

    function instantiate(
        address _challenger,
        address _claimer,
        bytes32 _initialHash,
        bytes32 _claimerFinalHash,
        uint _finalTime,
        uint _querySize,
        uint _roundDuration) public returns (uint256);

    function timeHash(uint256 _index, uint key) public view returns (bytes32);
    function divergenceTime(uint256 _index) public view returns (uint);
    function stateIsWaitingQuery(uint256 _index) public view returns (bool);
    function stateIsWaitingHashes(uint256 _index) public view returns (bool);
    function stateIsChallengerWon(uint256 _index) public view returns (bool);
    function stateIsClaimerWon(uint256 _index) public view returns (bool);
    function stateIsDivergenceFound(uint256 _index) public view returns (bool);
}
