pragma solidity 0.4.24;
import "../MMInstantiator.sol";
  contract MMInstantiatorTestAux is MMInstantiator {
    constructor() public {}
    function setState(uint index, state toState) public {
      instance[index].currentState = toState;
    }
 }
