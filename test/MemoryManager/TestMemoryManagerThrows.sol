pragma solidity 0.4.24;
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/MMInstantiator.sol";
import "../../contracts/SimpleMemoryInstantiator.sol";
import "../../contracts/testAuxiliaries/MMInstantiatorTestAux.sol";

contract TestMemoryManagerThrows is MMInstantiatorTestAux, SimpleMemoryInstantiator {

  function testProveReadAndProveWrite() public {
    MMInstantiatorTestAux mmInstance = MMInstantiatorTestAux(DeployedAddresses.MMInstantiatorTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(mmInstance));
    bytes32[] memory bytesArray = new bytes32[](61);

    for(uint i = 0; i < 61; i++){
      bytesArray[i] = "ab";

    }
    uint newIndex =  mmInstance.instantiate(address(aliceThrowProxy), 0x321,"initalHash");

    //set wrong state
    mmInstance.setState(newIndex, state.WaitingReplay);
    
    MMInstantiator(address(aliceThrowProxy)).proveRead(newIndex, 3,"initial", bytesArray);
   
    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Prove Read Transaction should fail, state should be WaitingProofs");
   
    MMInstantiator(address(aliceThrowProxy)).proveWrite(newIndex, 0,"oldValue", "newValue", bytesArray);
   
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Prove write Transaction should fail, state should be WaitingProofs");


    //set correct state
    mmInstance.setState(newIndex, state.WaitingProofs);

    MMInstantiator(address(aliceThrowProxy)).proveRead(newIndex, 0,"initial", bytesArray);
   
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, proof != instance[index].newHash");

    MMInstantiator(address(aliceThrowProxy)).proveWrite(newIndex, 0,"oldValue", "newValue", bytesArray);
   
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, proof != instance[index].newHash");
  }

  function testFinishProofPhase() public {
    MMInstantiatorTestAux mmInstance = MMInstantiatorTestAux(DeployedAddresses.MMInstantiatorTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(mmInstance));
   uint newIndex =  mmInstance.instantiate(address(aliceThrowProxy), 0x321,"initalHash");

    //set wrong state
    mmInstance.setState(newIndex, state.WaitingReplay);
   
    MMInstantiator(address(aliceThrowProxy)).finishProofPhase(newIndex);
    
    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, state should be WaitinProofs");

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
  function() public {
    data = msg.data;
  }
  function execute() public returns (bool) {
    return target.call(data);
  }
}
