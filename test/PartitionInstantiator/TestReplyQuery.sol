pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestReplyQuery is PartitionInstantiator{
  uint nextIndex = 0;
  address mockAddress1 = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;
 
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);

  function testReplyQuery() public {
    uint newIndex = instantiate(mockAddress1, msg.sender, "initiaHash", "finalHash", 3000000, 19, 150);   
    
    bytes32[] memory mockReplyArray = new bytes32[](instance[newIndex].querySize);
    uint256[] memory mockPostedTimes = new uint[](instance[newIndex].querySize);
    
    slice(newIndex, 1, instance[newIndex].querySize); 

    //populate replyArray and PostedTimes with correct values
    for(uint i = 0; i < instance[newIndex].querySize; i++){
      mockReplyArray[i] = "0123";
    }
    for(uint i = 0; i < instance[newIndex].querySize; i++){
      mockPostedTimes[i] = instance[newIndex].queryArray[i];
    }

    instance[newIndex].currentState = state.WaitingHashes;
    replyQuery(newIndex, mockPostedTimes, mockReplyArray);

    Assert.equal(uint(instance[newIndex].currentState),uint(state.WaitingQuery), "State should be waiting query");

    for(uint i = 0; i < instance[newIndex].querySize; i++){
      Assert.isTrue(instance[newIndex].timeSubmitted[mockPostedTimes[i]], "postedTimes must be true");
      Assert.equal(instance[newIndex].timeHash[mockPostedTimes[i]], mockReplyArray[i], "posted times and postedHashes should match");
    }
    
    newIndex = instantiate(mockAddress1, msg.sender, "initiaHash", "finalHash", 3000000, 19, 150);   
    slice(newIndex, 1, instance[newIndex].querySize); 

    for(uint i = 0; i < instance[newIndex].querySize; i++){
      mockReplyArray[i] = bytes32(i);
    }
    for(uint i = 0; i < instance[newIndex].querySize; i++){
      mockPostedTimes[i] = instance[newIndex].queryArray[i];
    }
    instance[newIndex].currentState = state.WaitingHashes;
    replyQuery(newIndex, mockPostedTimes, mockReplyArray);

    Assert.equal(uint(instance[newIndex].currentState),uint(state.WaitingQuery), "State should be waiting query");

    for(uint i = 0; i < instance[newIndex].querySize; i++){
      Assert.isTrue(instance[newIndex].timeSubmitted[mockPostedTimes[i]], "postedTimes must be true");
      Assert.equal(instance[newIndex].timeHash[mockPostedTimes[i]], mockReplyArray[i], "posted times and postedHashes should match");
    }
 }
}

