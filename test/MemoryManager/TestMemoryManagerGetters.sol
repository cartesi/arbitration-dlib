pragma solidity 0.4.24;
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/MMInstantiator.sol";
import "../../contracts/SimpleMemoryInstantiator.sol";
import "../../contracts/testAuxiliaries/MMInstantiatorTestAux.sol";

contract TestMemoryManagerGetters is MMInstantiatorTestAux, SimpleMemoryInstantiator {

  function testGetters() public {
    address provider = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
    address client = 0x583031D1113aD414F02576BD6afaBfb302140225; 
    bytes32 initialHash = bytes32("mockHash");
    bytes32 newHash = bytes32("newHash");

    MMInstantiatorTestAux mmInstance = MMInstantiatorTestAux(DeployedAddresses.MMInstantiatorTestAux());

    uint newIndex =  mmInstance.instantiate(provider, client, initialHash);
   
    Assert.equal(mmInstance.provider(newIndex), provider, "Provider address should match");
    Assert.equal(mmInstance.client(newIndex), client, "Client address should match");
    Assert.equal(mmInstance.initialHash(newIndex), initialHash, "Initial hash should match");

    mmInstance.setNewHashAtIndex(newIndex, newHash);

    Assert.equal(mmInstance.newHash(newIndex), newHash, "newHash should match");

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
