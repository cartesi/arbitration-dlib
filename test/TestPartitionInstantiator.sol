pragma solidity 0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/PartitionInstantiator.sol";

contract TestPartitionInstantiator is PartitionInstantiator{
  uint nextIndex = 0;
  function testInstantiate() public {
    uint newIndex = instantiate(0x123,0x231,"initialHash","finalHash", 50000, 15, 55);   
    
    Assert.equal(newIndex, nextIndex, "Partition index should be equal to nextIndex"); 
    Assert.equal(instance[0].roundDuration, 55, "round duration should be 55");
    Assert.equal(instance[0].challenger, 0x123, "Challenger address should be 0x123");
    Assert.equal(instance[0].claimer, 0x231, "Claimer address should be 0x231");
    Assert.equal(instance[0].finalTime, 50000, "Final time should be 50000");
    Assert.equal(instance[0].timeHash[0], "initialHash", "Initial hash should be initialHash");
    Assert.equal(instance[0].timeHash[instance[0].finalTime], "finalHash", "Final hash should be finalHash");
    Assert.equal(instance[0].querySize, 15, "querysize should be equal to 15");
    
    nextIndex++; //Always increment after instance tests
    
    newIndex = instantiate(0x222,0x333,"otherInitialHash","otherFinalHash", 3000000, 19, 150);
    Assert.equal(newIndex, nextIndex, "Partition index should be equal to nextIndex");

    Assert.equal(instance[1].challenger, 0x222, "Challenger address should be 0x222");
    Assert.equal(instance[1].claimer, 0x333, "Claimer address should be 0x333");
    Assert.equal(instance[1].finalTime, 3000000, "Final time should be 3000000");
    Assert.equal(instance[1].timeHash[0], "otherInitialHash", "Initial hash should be otherInitialHash");
    Assert.equal(instance[1].timeHash[instance[1].finalTime], "otherFinalHash", "Final hash should be otherFinalHash");
    Assert.equal(instance[1].querySize, 19, "querysize should be equal to 15");
    nextIndex++; //Always increment after instance tests
 }

  function testSlice() public {
  }

  function testReplyQuery() public {
  }

  function testMakeQuery() public {
  }

  function testClaimVictoryByTime() public {
  }
  
  function testPresentDivergence() public {
  }

  function testDivergenceTime() public {
  }

  function testTimeSubmitted() public {
  }

  function testTimeHash() public {
  }

  function testQueryArray() public {
  }

}
