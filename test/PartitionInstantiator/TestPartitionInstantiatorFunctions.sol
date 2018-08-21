pragma solidity 0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestPartitionInstantiatorFunctions is PartitionInstantiator{
  uint nextIndex = 0;
    
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);

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

    newIndex = instantiate(0x222,msg.sender,"otherInitialHash","otherFinalHash", 3000000, 19, 300);
    nextIndex++; //Always increment after instance tests
    
    newIndex = instantiate(msg.sender,0x123,"otherInitialHash","otherFinalHash", 3000000, 5, 150);
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
    
    uint currentIndex = 1;
    bytes32[] memory replyArray = new bytes32[](instance[currentIndex].querySize);
    uint256[] memory postedTimes = new uint[](instance[currentIndex].querySize);

    for(uint i = 0; i < instance[currentIndex].querySize; i++){
      replyArray[i] = "0123";
    }
    for(i = 0; i < instance[currentIndex].querySize; i++){
      postedTimes[i] = instance[currentIndex].queryArray[i];
    }
    instance[currentIndex].currentState = state.WaitingHashes;
    replyQuery(currentIndex, postedTimes, replyArray);

    Assert.equal(uint(instance[currentIndex].currentState),uint(state.WaitingQuery), "State should be waiting query");

    for(i = 0; i < instance[currentIndex].querySize; i++){
      Assert.isTrue(instance[currentIndex].timeSubmitted[postedTimes[i]], "postedTimes must be true");
      Assert.equal(instance[currentIndex].timeHash[postedTimes[i]], replyArray[i], "posted times and postedHashes should match");
    }

    currentIndex = 2;

    for(i = 0; i < instance[currentIndex].querySize; i++){
      replyArray[i] = "0123";
    }
    for(i = 0; i < instance[currentIndex].querySize; i++){
      postedTimes[i] = instance[currentIndex].queryArray[i];
    }
    instance[currentIndex].currentState = state.WaitingHashes;
    replyQuery(currentIndex, postedTimes, replyArray);

    Assert.equal(uint(instance[currentIndex].currentState),uint(state.WaitingQuery), "State should be waiting query");

    for(i = 0; i < instance[currentIndex].querySize; i++){
      Assert.isTrue(instance[currentIndex].timeSubmitted[postedTimes[i]], "postedTimes must be true");
      Assert.equal(instance[currentIndex].timeHash[postedTimes[i]], replyArray[i], "posted times and postedHashes should match");
    }
  }

  function testMakeQuery() public {
    
    uint newIndex;
    uint queryPiece;
    uint leftPoint;
    uint rightPoint;     

    for(uint i = 1; i < 5; i++) {
      newIndex = instantiate(msg.sender,0x231,"initialHash","finalHash", 5000 * i, i * 3, i * 55);   
      queryPiece = instance[newIndex].querySize - 2;
      leftPoint  = instance[newIndex].queryArray[queryPiece];
      rightPoint = instance[newIndex].queryArray[queryPiece + 1];
      instance[newIndex].currentState = state.WaitingQuery;
      makeQuery(newIndex, queryPiece, leftPoint, rightPoint);

      Assert.equal(uint(instance[newIndex].currentState), uint(state.WaitingHashes), "State should be waiting hashes");
      Assert.equal(instance[newIndex].timeOfLastMove, now, "time of last move should be now");
    }
  }

  function testClaimVictoryByTime() public {
    uint newIndex;
    for (uint i = 1;i < 6; i++){
      if(i % 2 == 0){
        newIndex = instantiate(msg.sender,0x231, "initialHash","finalHash", 5000 * i, 3 * i, 55 * i);
        instance[newIndex].currentState = state.WaitingHashes;
      }else{
        newIndex = instantiate(0x312, msg.sender,"initialHash","finalHash", 5000 * i, 3 * i, 55 * i);
        instance[newIndex].currentState = state.WaitingQuery;
      } 
         
      instance[newIndex].timeOfLastMove = 0; 
      instance[newIndex].roundDuration = 0;

      claimVictoryByTime(newIndex);
      Assert.equal(uint(instance[newIndex].currentState), i%2 == 0? uint(state.ChallengerWon):uint(state.ClaimerWon), "State should be waiting hashes");
    }
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

