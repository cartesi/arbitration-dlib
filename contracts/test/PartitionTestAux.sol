pragma solidity ^0.5.0;

import "../PartitionInstantiator.sol";


contract PartitionTestAux is PartitionInstantiator {

    function setState(uint partitionIndex, state toState) public {
        instance[partitionIndex].currentState = toState;
    }

    function setFinalTimeAtIndex(uint partitionIndex, uint finalTime) public {
        instance[partitionIndex].finalTime = finalTime;
    }

    function setTimeOfLastMoveAtIndex(uint partitionIndex, uint timeOfLastMove) public {
        instance[partitionIndex].timeOfLastMove = timeOfLastMove;
    }

    function setRoundDurationAtIndex(uint partitionIndex, uint roundDuration) public {
        instance[partitionIndex].roundDuration = roundDuration;
    }

    function setDivergenceTimeAtIndex(uint partitionIndex, uint divergenceTime) public {
        instance[partitionIndex].divergenceTime = divergenceTime;
    }

    function setTimeSubmittedAtIndex(uint partitionIndex, uint timeIndex) public {
        instance[partitionIndex].timeSubmitted[timeIndex] = true;
    }

    function setTimeHashAtIndex(uint partitionIndex, uint timeIndex, bytes32 timeHash) public {
        instance[partitionIndex].timeHash[timeIndex] = timeHash;
    }

    function setQueryArrayAtIndex(uint partitionIndex, uint queryIndex, uint query) public {
        instance[partitionIndex].queryArray[queryIndex] = query;
    }

    function getQueryArrayAtIndex(uint partitionIndex, uint queryIndex) public view    returns (uint) {
        return instance[partitionIndex].queryArray[queryIndex];
    }

    function getTimeSubmittedAtIndex(uint partitionIndex, uint timeIndex) public view returns (bool) {
        return instance[partitionIndex].timeSubmitted[timeIndex];
    }

    function getChallengerAtIndex(uint256 partitionIndex) public view returns (address) {
        return instance[partitionIndex].challenger;
    }

    function getClaimerAtIndex(uint256 partitionIndex) public view returns (address) {
        return instance[partitionIndex].claimer;
    }

    function getFinalTimeAtIndex(uint256 partitionIndex) public view returns (uint) {
        return instance[partitionIndex].finalTime;
    }

    function getQuerySize(uint256 partitionIndex) public view returns (uint) {
        return instance[partitionIndex].querySize;
    }

    function getTimeOfLastMoveAtIndex(uint256 partitionIndex) public view returns (uint) {
        return instance[partitionIndex].timeOfLastMove;
    }

    function getRoundDurationAtIndex(uint256 partitionIndex) public view returns (uint) {
        return instance[partitionIndex].roundDuration;
    }

    function getTimeHashAtIndex(uint partitionIndex, uint timeIndex) public view returns (bytes32) {
        return instance[partitionIndex].timeHash[timeIndex];
    }

    function doSlice(uint256 _index, uint leftPoint, uint rightPoint) public {
        slice(_index, leftPoint, rightPoint);
    }
}
