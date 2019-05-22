pragma solidity ^0.5.0;

import "../PartitionInstantiator.sol";

contract PartitionTestAux is PartitionInstantiator {
  constructor() public {}

  function setState(uint partitionIndex, state toState) public{
    instance[partitionIndex].currentState = toState;
  }

  function setTimeSubmittedAtIndex(uint partitionIndex, uint timeIndex) public {
    instance[partitionIndex].timeSubmitted[timeIndex] = true;
  }

  function getQueryArrayAtIndex(uint partitionIndex, uint queryIndex) public view  returns (uint) {
    return instance[partitionIndex].queryArray[queryIndex];
  }

  function getTimeSubmittedAtIndex(uint partitionIndex, uint timeIndex) public view returns (bool) {
    return instance[partitionIndex].timeSubmitted[timeIndex];
  }
}
