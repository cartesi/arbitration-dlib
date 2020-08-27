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

pragma solidity ^0.7.0;

import "../PartitionInstantiator.sol";

contract PartitionTestAux is PartitionInstantiator {
    function setState(uint256 partitionIndex, state toState) public {
        instance[partitionIndex].currentState = toState;
    }

    function setFinalTimeAtIndex(uint256 partitionIndex, uint256 finalTime)
        public
    {
        instance[partitionIndex].finalTime = finalTime;
    }

    function setTimeOfLastMoveAtIndex(
        uint256 partitionIndex,
        uint256 timeOfLastMove
    ) public {
        instance[partitionIndex].timeOfLastMove = timeOfLastMove;
    }

    function setRoundDurationAtIndex(
        uint256 partitionIndex,
        uint256 roundDuration
    ) public {
        instance[partitionIndex].roundDuration = roundDuration;
    }

    function setDivergenceTimeAtIndex(
        uint256 partitionIndex,
        uint256 divergenceTime
    ) public {
        instance[partitionIndex].divergenceTime = divergenceTime;
    }

    function setTimeSubmittedAtIndex(uint256 partitionIndex, uint256 timeIndex)
        public
    {
        instance[partitionIndex].timeSubmitted[timeIndex] = true;
    }

    function setTimeHashAtIndex(
        uint256 partitionIndex,
        uint256 timeIndex,
        bytes32 timeHash
    ) public {
        instance[partitionIndex].timeHash[timeIndex] = timeHash;
    }

    function setQueryArrayAtIndex(
        uint256 partitionIndex,
        uint256 queryIndex,
        uint256 query
    ) public {
        instance[partitionIndex].queryArray[queryIndex] = query;
    }

    function setQuerySizeAtIndex(uint256 partitionIndex, uint256 querySize)
        public
    {
        instance[partitionIndex].querySize = querySize;
    }

    function getQueryArrayAtIndex(uint256 partitionIndex, uint256 queryIndex)
        public
        view
        returns (uint256)
    {
        return instance[partitionIndex].queryArray[queryIndex];
    }

    function getTimeSubmittedAtIndex(uint256 partitionIndex, uint256 timeIndex)
        public
        view
        returns (bool)
    {
        return instance[partitionIndex].timeSubmitted[timeIndex];
    }

    function getChallengerAtIndex(uint256 partitionIndex)
        public
        view
        returns (address)
    {
        return instance[partitionIndex].challenger;
    }

    function getClaimerAtIndex(uint256 partitionIndex)
        public
        view
        returns (address)
    {
        return instance[partitionIndex].claimer;
    }

    function getFinalTimeAtIndex(uint256 partitionIndex)
        public
        view
        returns (uint256)
    {
        return instance[partitionIndex].finalTime;
    }

    function getQuerySizeAtIndex(uint256 partitionIndex)
        public
        view
        returns (uint256)
    {
        return instance[partitionIndex].querySize;
    }

    function getTimeOfLastMoveAtIndex(uint256 partitionIndex)
        public
        view
        returns (uint256)
    {
        return instance[partitionIndex].timeOfLastMove;
    }

    function getRoundDurationAtIndex(uint256 partitionIndex)
        public
        view
        returns (uint256)
    {
        return instance[partitionIndex].roundDuration;
    }

    function getTimeHashAtIndex(uint256 partitionIndex, uint256 timeIndex)
        public
        view
        returns (bytes32)
    {
        return instance[partitionIndex].timeHash[timeIndex];
    }

    function doSlice(
        uint256 _index,
        uint256 leftPoint,
        uint256 rightPoint
    ) public {
        slice(_index, leftPoint, rightPoint);
    }
}
