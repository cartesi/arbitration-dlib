pragma solidity 0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/PartitionInstantiator.sol";

contract TestPartitionInstantiator is PartitionInstantiator{
  uint nextIndex = 0;
  function testInstantiate() public {
    uint newIndex = instantiate(msg.sender,0x231,"initialHash","finalHash", 50000, 15, 55);   
    
    Assert.equal(newIndex, nextIndex, "Partition index should be equal to nextIndex"); 
    Assert.equal(instance[0].roundDuration, 55, "round duration should be 55");
    Assert.equal(instance[0].challenger, msg.sender, "Challenger address should be msg.sender");
    Assert.equal(instance[0].claimer, 0x231, "Claimer address should be 0x231");
    Assert.equal(instance[0].finalTime, 50000, "Final time should be 50000");
    Assert.equal(instance[0].timeHash[0], "initialHash", "Initial hash should be initialHash");
    Assert.equal(instance[0].timeHash[instance[0].finalTime], "finalHash", "Final hash should be finalHash");
    Assert.equal(instance[0].querySize, 15, "querysize should be equal to 15");
    
    nextIndex++; //Always increment after instance tests
    
    newIndex = instantiate(0x222,msg.sender,"otherInitialHash","otherFinalHash", 3000000, 19, 150);
    Assert.equal(newIndex, nextIndex, "Partition index should be equal to nextIndex");

    Assert.equal(instance[1].challenger, 0x222, "Challenger address should be 0x222");
    Assert.equal(instance[1].claimer, msg.sender, "Claimer address should be msg.sender");
    Assert.equal(instance[1].finalTime, 3000000, "Final time should be 3000000");
    Assert.equal(instance[1].timeHash[0], "otherInitialHash", "Initial hash should be otherInitialHash");
    Assert.equal(instance[1].timeHash[instance[1].finalTime], "otherFinalHash", "Final hash should be otherFinalHash");
    Assert.equal(instance[1].querySize, 19, "querysize should be equal to 19");
    nextIndex++; //Always increment after instance tests

    //instantiate n partitions
    uint n = nextIndex + 5;
    uint i = nextIndex;
    for (i; i < n; i++) {
      newIndex = instantiate(0x222,0x333,"otherInitialHash","otherFinalHash", 3000000, 19, 55 + i);
      Assert.equal(newIndex, nextIndex, "Partition index should be equal to nextIndex");
      Assert.equal(instance[i].roundDuration, 55 + i, "round duration should be 55 + i");
    nextIndex++;
    } 
  }
  function testSlice() public {
  //if intervalLength < 2 * queryLastIndex
    uint leftPoint = 2;
    uint rightPoint = 5;
   
    slice(0,leftPoint, rightPoint);

    for(uint i = 0; i < instance[0].querySize - 1; i++){
      if(leftPoint + i < rightPoint){
        Assert.equal(instance[0].queryArray[i], leftPoint + i,"Queryarray[i] must be = leftPoint +i");
      }else{
        Assert.equal(instance[0].queryArray[i], rightPoint, "queryArray[i] must be equal rightPoint"); 
      }
    }

    leftPoint = 50;
    rightPoint = 55;
 
    slice(3,leftPoint, rightPoint);

    for(i = 0; i < instance[3].querySize - 1; i++){
      if(leftPoint + i < rightPoint){
        Assert.equal(instance[3].queryArray[i], leftPoint + i,"Queryarray[i] must be = leftPoint +i");
      }else{
        Assert.equal(instance[3].queryArray[i], rightPoint, "queryArray[i] must be equal rightPoint"); 
      }
    }
    leftPoint = 0;
    rightPoint = 1;
 
    slice(3,leftPoint, rightPoint);

    for(i = 0; i < instance[3].querySize - 1; i++){
      if(leftPoint + i < rightPoint){
        Assert.equal(instance[3].queryArray[i], leftPoint + i,"Queryarray[i] must be = leftPoint +i");
      }else{
        Assert.equal(instance[3].queryArray[i], rightPoint, "queryArray[i] must be equal rightPoint"); 
      }
    }
    //else
    leftPoint = 1;
    rightPoint = 600;
   
    slice(1,leftPoint, rightPoint);

    uint divisionLength = (rightPoint - leftPoint) / (instance[1].querySize - 1);
    for (i = 0; i < instance[1].querySize - 1; i++) {
      Assert.equal(instance[1].queryArray[i], leftPoint + i * divisionLength, "slice else path");
    }
    leftPoint = 150;
    rightPoint = 600;
   
    slice(1,leftPoint, rightPoint);

    divisionLength = (rightPoint - leftPoint) / (instance[1].querySize - 1);
    for (i = 0; i < instance[1].querySize - 1; i++) {
      Assert.equal(instance[1].queryArray[i], leftPoint + i * divisionLength, "slice else path");
    }

  }

  function testReplyQuery() public {
    bytes32[] memory replyArray = new bytes32[](instance[1].querySize);
    uint256[] memory postedTimes = new uint[](instance[1].querySize);


    for(uint i = 0; i < instance[1].querySize; i++){
      replyArray[i] = "0123";
    }
    for(i = 0; i < instance[1].querySize; i++){
      postedTimes[i] = instance[1].queryArray[i];
    }
    instance[1].currentState = state.WaitingHashes;
    replyQuery(1, postedTimes, replyArray);

    Assert.equal(uint(instance[1].currentState),uint(state.WaitingQuery), "State should be waiting query");
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

  //Test throws/requires
  function testThrow() public { 
  }

}

// Proxy contract for testing throws
contract ThrowProxy {
  address public target;
  bytes data;

  function ThrowProxy(address _target) {
    target = _target;
  }

  //prime the data using the fallback function.
  function() {
    data = msg.data;
  }

  function execute() returns (bool) {
    return target.call(data);
  }
}
