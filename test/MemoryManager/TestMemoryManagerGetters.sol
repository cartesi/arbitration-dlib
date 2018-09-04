pragma solidity 0.4.24;
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/MMInstantiator.sol";
import "../../contracts/SimpleMemoryInstantiator.sol";
import "../../contracts/testAuxiliaries/MMInstantiatorTestAux.sol";

contract TestMemoryManagerGetters is MMInstantiatorTestAux {

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

  function testStateGetters() public {
    address provider = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
    address client = 0x583031D1113aD414F02576BD6afaBfb302140225; 
    bytes32 initialHash = bytes32("mockHash");
  
    MMInstantiatorTestAux mmInstance = MMInstantiatorTestAux(DeployedAddresses.MMInstantiatorTestAux());

    uint newIndex =  mmInstance.instantiate(provider, client, initialHash);
    
    mmInstance.setState(newIndex, state.WaitingReplay);

    Assert.equal(mmInstance.stateIsWaitingReplay(newIndex), true, "state  should be WaitingReplay");
    Assert.equal(mmInstance.stateIsWaitingProofs(newIndex), false, "state  shouldint be WaitingtProofs");
    Assert.equal(mmInstance.stateIsFinishedReplay(newIndex), false, "state  shouldint be FinishedReplayed");

    mmInstance.setState(newIndex, state.WaitingProofs);
    Assert.equal(mmInstance.stateIsWaitingReplay(newIndex), false, "state  shouldnt be WaitingReplay");
    Assert.equal(mmInstance.stateIsWaitingProofs(newIndex), true, "state  should be WaitingtProofs");
    Assert.equal(mmInstance.stateIsFinishedReplay(newIndex), false, "state  shouldint be FinishedReplayed");

    mmInstance.setState(newIndex, state.FinishedReplay);
    Assert.equal(mmInstance.stateIsWaitingReplay(newIndex), false, "state  shouldnt be WaitingReplay");
    Assert.equal(mmInstance.stateIsWaitingProofs(newIndex), false, "state  shouldnt be WaitingtProofs");
    Assert.equal(mmInstance.stateIsFinishedReplay(newIndex), true, "state  should be FinishedReplayed");

  }
}
