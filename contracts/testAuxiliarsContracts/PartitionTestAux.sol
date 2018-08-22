pragma solidity 0.4.24;

import "../PartitionInstantiator.sol";

contract PartitionTestAux is PartitionInstantiator {
  function PartitionTestAux(){}

  function getQueryArrayAtIndex(uint partitionIndex, uint queryIndex) returns (uint) {
    return instance[partitionIndex].queryArray[queryIndex];
  }

  function setState(uint partitionIndex, state toState){
    instance[partitionIndex].currentState = toState;
  }

  function setTimeSubmittedAtIndex(uint partitionIndex, uint timeIndex ){
    instance[partitionIndex].timeSubmitted[timeIndex] = true;
  }
  function getTimeSubmittedAtIndex(uint partitionIndex, uint timeIndex) returns (bool) {
    return instance[partitionIndex].timeSubmitted[timeIndex];
  }
}

