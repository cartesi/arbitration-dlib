pragma solidity 0.4.24;

import "./PartitionInstantiator.sol";

contract PartitionTestAux is PartitionInstantiator {
  function PartitionTestAux(){}

  function getQueryArrayAtIndex(uint partitionIndex, uint queryIndex) returns (uint) {
    return instance[partitionIndex].queryArray[queryIndex];
  }

  function setState(uint partitionIndex, state toState){
    instance[partitionIndex].currentState = toState;
  }
}

