pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestInstantiator is PartitionInstantiator{
  uint nextIndex = 0;
    
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  //Arbirtrary numbers to simulate hashes
  uint initialHashSeed = 5;
  uint finalHashSeed = 225;

  function testInstantiate() public {
    address mockAddress1 = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;
    address mockAddress2 = 0x00513219f383C9B21cFfffA3B14C1B06741E5C32;
    nextIndex = 0; 
    uint newIndex = 19;

    //more than 9 instances contract run out of gas
    for(uint i = 3; i < 12; i++){
      if(i % 2 == 0) {
        newIndex = instantiate(msg.sender,mockAddress1,bytes32(i+ initialHashSeed), bytes32(i + finalHashSeed), 50000 * i, i, 55 * i);   
        Assert.equal(instance[newIndex].challenger, msg.sender, "Challenger address should be msg.sender");
        Assert.equal(instance[newIndex].claimer, mockAddress1, "Claimer address should match");
        Assert.equal(instance[newIndex].querySize, i, "querysize should match");

      }else{
        newIndex = instantiate(mockAddress2, msg.sender,bytes32(i+ initialHashSeed),bytes32(i + finalHashSeed),i * 50000, i+7, i * 55);   
        Assert.equal(instance[newIndex].challenger,mockAddress2, "Challenger address should be msg.sender");
        Assert.equal(instance[newIndex].claimer, msg.sender, "Claimer address should be 0x231");
        Assert.equal(instance[newIndex].querySize, i+7, "querysize should be equal to 15");
      }
        
      Assert.equal(newIndex, nextIndex, "Partition index should be equal to nextIndex"); 
      Assert.equal(instance[newIndex].roundDuration, 55 * i, "round duration should be 55 * i");
      Assert.equal(instance[newIndex].finalTime, 50000 * i, "Final time should be 50000 * i");
      Assert.equal(instance[newIndex].timeHash[0], bytes32(i+ initialHashSeed), "Initial hash should match");
      Assert.equal(instance[newIndex].timeHash[instance[newIndex].finalTime], bytes32(i + finalHashSeed), "Final hash should match");
      
      nextIndex++; //Always increment after instance tests
    }
  }
}

