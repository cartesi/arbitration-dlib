pragma solidity 0.5;
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/MMInstantiator.sol";
import "../../contracts/SimpleMemoryInstantiator.sol";
import "../../contracts/testAuxiliaries/MMInstantiatorTestAux.sol";

contract TestMemoryManagerThrowsPart2 is MMInstantiatorTestAux {

  function testReadAndWrite() public {
    uint64 position = 0;
    
    bool[] memory listOfWasRead = new bool[](17);
    bool[] memory listOfWasNotRead = new bool[](17);
    uint64[] memory listOfPositions = new uint64[](17);
    bytes8[] memory listOfValues = new bytes8[](17);

    for(uint64 i = 0; i < listOfWasRead.length - 1; i++){
      listOfWasRead[i] = true;
      listOfWasNotRead[i] = false;
      listOfPositions[i] = i * 8;
      listOfValues[i] = bytes8(i);
    }
    //add unaligned position for testing
    listOfWasRead[listOfWasRead.length - 1] = true;
    listOfWasNotRead[listOfWasNotRead.length - 1] = false;
    listOfPositions[listOfWasRead.length - 1] = 7;
    listOfValues[listOfWasRead.length - 1] = bytes8(uint64(3));
    
    MMInstantiatorTestAux mmInstance = MMInstantiatorTestAux(DeployedAddresses.MMInstantiatorTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(mmInstance));
    uint newIndex =  mmInstance.instantiate(address(0x321), address(aliceThrowProxy), "initalHash");
    uint secondIndex =  mmInstance.instantiate(address(0x321), address(aliceThrowProxy), "initalHash");

    //set history pointer to first position
    mmInstance.setHistoryPointerAtIndex(newIndex, 0);
    mmInstance.setHistoryPointerAtIndex(secondIndex, 0);

    //create ReadWrites and add it to the history
    mmInstance.setHistoryAtIndex(newIndex, listOfWasRead, listOfPositions, listOfValues);
    mmInstance.setHistoryAtIndex(secondIndex, listOfWasNotRead, listOfPositions, listOfValues);

    //readWrapper - throproxy does not work with return values
    MMInstantiatorTestAux(address(aliceThrowProxy)).write(secondIndex, position, listOfValues[position]);
    
   
    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Write Transaction should fail, state should be WaitingReplay");

    MMInstantiatorTestAux(address(aliceThrowProxy)).readWrapper(newIndex, position);
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, state should be WaitingProofs");


    //set correct state
    mmInstance.setState(newIndex, state.WaitingReplay);
    mmInstance.setState(secondIndex, state.WaitingReplay);   
    
    //set unaligned position
    position = 7;

    //set history pointer to unaligned position
    mmInstance.setHistoryPointerAtIndex(newIndex, listOfWasRead.length - 1);
    mmInstance.setHistoryPointerAtIndex(secondIndex, listOfWasNotRead.length - 1);

    MMInstantiatorTestAux(address(aliceThrowProxy)).readWrapper(newIndex, position);
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, position not aligned");

    MMInstantiatorTestAux(address(aliceThrowProxy)).write(secondIndex, position, listOfValues[position]);
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Write Transaction should fail, position not aligned");


    //create new instance, for separate history
    newIndex =  mmInstance.instantiate(address(0x321), address(aliceThrowProxy), "initalHash");
    secondIndex =  mmInstance.instantiate(address(0x321), address(aliceThrowProxy), "initalHash");

    //set correct state
    mmInstance.setState(newIndex, state.WaitingReplay);
    mmInstance.setState(secondIndex, state.WaitingReplay);

    //set aligned position
    position = 8;
    //set history pointer to second position
    mmInstance.setHistoryPointerAtIndex(newIndex, 1);
    mmInstance.setHistoryPointerAtIndex(secondIndex, 1);
   
    //add incorrect values to was read list
    listOfWasRead[1] = false;
    listOfWasNotRead[1] = true;

    //insert updated listOfWas/Not/Read
    mmInstance.setHistoryAtIndex(newIndex, listOfWasRead, listOfPositions, listOfValues);
    mmInstance.setHistoryAtIndex(secondIndex, listOfWasNotRead, listOfPositions, listOfValues);

    MMInstantiatorTestAux(address(aliceThrowProxy)).readWrapper(newIndex, position);
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, wasRead is false");

    MMInstantiatorTestAux(address(aliceThrowProxy)).write(secondIndex, position, listOfValues[1]);
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Write Transaction should fail, wasRead is true");


    //set aligned position
    position = 24;
    //set history pointer to second(should be third) position
    mmInstance.setHistoryPointerAtIndex(newIndex, 2);
    mmInstance.setHistoryPointerAtIndex(secondIndex, 2);

    MMInstantiatorTestAux(address(aliceThrowProxy)).readWrapper(newIndex, position);
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, pointInHistory.position != position");

    MMInstantiatorTestAux(address(aliceThrowProxy)).write(secondIndex, position, listOfValues[2]);

    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, pointInHistory.position != position");
    
    //aligned position
    position = 16;
    MMInstantiatorTestAux(address(aliceThrowProxy)).write(secondIndex, position, bytes8(uint64(7)));

    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, pointInHistory.position != position");

  }

}

// Proxy contract for testing throws
contract ThrowProxy {
  address public target;
  bytes data;
   constructor(address _target) public{
    target = _target;
  }
  //prime the data using the fallback function.
  function() external {
    data = msg.data;
  }
  function execute() public returns (bool) {
    bool r;
    (r, ) = target.call(data);
    return r;
  }
}
