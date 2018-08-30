pragma solidity 0.4.24;
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/MMInstantiator.sol";
import "../../contracts/SimpleMemoryInstantiator.sol";
import "../../contracts/testAuxiliaries/MMInstantiatorTestAux.sol";

contract TestMemoryManagerThrows is MMInstantiator, SimpleMemoryInstantiator {

  function testProveRead(){
    MMInstantiatorTestAux mmInstance = MMInstantiatorTestAux(DeployedAddresses.MMInstantiatorTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(mmInstance));
    bytes32[] memory bytesArray = new bytes32[](3);

    for(uint i = 0; i < 3; i++){
      bytesArray[i] = "ab";

    }
    uint newIndex =  mmInstance.instantiate(address(aliceThrowProxy), 0x321,"initalHash");

    //set wrong state
    mmInstance.setState(newIndex, state.WaitingReplay);
    MMInstantiator(address(aliceThrowProxy)).proveRead(newIndex, 3,"initial", bytesArray);
   
    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, state should be WaitingProofs");

    //set correct state
    mmInstance.setState(newIndex, state.WaitingProofs);

    MMInstantiator(address(aliceThrowProxy)).proveRead(newIndex, 3,"initial", bytesArray);
   
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, proof != instance[index].newHash");
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
