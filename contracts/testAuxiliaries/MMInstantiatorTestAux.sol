pragma solidity 0.4.24;
import "../MMInstantiator.sol";
  contract MMInstantiatorTestAux is MMInstantiator {
    constructor() public {}
    function setState(uint index, state toState) public {
      instance[index].currentState = toState;
    }
    function setHistoryPointerAtIndex(uint index, uint pointer) public {
      instance[index].historyPointer = pointer; 
    }

    function setHistoryAtIndex(uint index, bool[] listOfWasRead, uint64[] listOfPositions, bytes8[] listOfValues) public {
      for(uint i = 0; i < listOfWasRead.length; i++) {
        ReadWrite memory dummyReadWrite;
        dummyReadWrite.wasRead = listOfWasRead[i];
        dummyReadWrite.position = listOfPositions[i];
        dummyReadWrite.value = listOfValues[i];

        instance[index].history.push(dummyReadWrite);
      }
    }
    
    //Wrapper because ThrowProxy contract do not work with return values
    //https://github.com/trufflesuite/truffle/issues/1001
    function readWrapper(uint index, uint64 position) public {
      read(index, position); 
    }
 }
