pragma solidity 0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";
import "../../contracts/testAuxiliaries/PartitionTestAux.sol";

contract TestPartitionInstantiatorThrows is PartitionInstantiator{
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  bytes32[] wrongReplyArray = new bytes32[](3);
  uint256[] wrongPostedTimes = new uint[](3);

  //Test reply throws/requires
  function testReplyThrows() public { 
    PartitionTestAux partition = PartitionTestAux(DeployedAddresses.PartitionTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(partition));
    uint newIndex = partition.instantiate(address(0x2123),address(aliceThrowProxy),"initialHash","finalHash", 50000, 15, 55);   
      
    for(uint i = 0; i < 15; i++){
      replyArray[i] = "0123";
      postedTimes[i] = partition.getQueryArrayAtIndex(newIndex,i);
    }

    //Set Wrong State
    partition.setState(newIndex, state.WaitingQuery);
    
    //Reply Query with incorrect state
    PartitionInstantiator(address(aliceThrowProxy)).replyQuery(newIndex, postedTimes, replyArray); 
    
    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, state is not WaitingHashes");

    partition.setState(newIndex, state.WaitingHashes);
    
    //Reply Query with Posted Times of incorrect length
    PartitionInstantiator(address(aliceThrowProxy)).replyQuery(newIndex, wrongPostedTimes, replyArray); 
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, postedTimes.length != querySize"); 

    //Reply Query with Reply Array of incorrect length
    PartitionInstantiator(address(aliceThrowProxy)).replyQuery(newIndex, postedTimes, wrongReplyArray); 
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, replyArray.length != querySize"); 

  //Add wrong value on PostedTimes
  postedTimes[3] = postedTimes[3] + 5; 
  
  //Posted Time with incorrect value
  PartitionInstantiator(address(aliceThrowProxy)).replyQuery(newIndex, postedTimes, replyArray); 
    
  r = aliceThrowProxy.execute.gas(2000000)();
  Assert.equal(r, false, "Transaction should fail, state is not WaitingHashes");


  }
  //test makeQuery throws
  function testMakeQueryThrows() public {
    uint queryPiece = 5;
    PartitionTestAux partition = PartitionTestAux(DeployedAddresses.PartitionTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(partition));
    uint newIndex = partition.instantiate(address(aliceThrowProxy),address(0x123),"initialHash","finalHash", 50000, 15, 55);   
   partition.setState(newIndex, state.WaitingQuery);
 
    //Make query with incorrect queryPiece
  PartitionInstantiator(address(aliceThrowProxy)).makeQuery(newIndex, 300, 0, 1); 
    
  bool r = aliceThrowProxy.execute.gas(2000000)();
  Assert.equal(r, false, "Transaction should fail, queryPiece is bigger than instance.querySize -1");

    //Make query with incorrect leftPoint
  PartitionInstantiator(address(aliceThrowProxy)).makeQuery(newIndex, queryPiece, 0, partition.getQueryArrayAtIndex(newIndex, queryPiece + 1)); 
  
  partition.setState(newIndex, state.WaitingQuery);
    
  r = aliceThrowProxy.execute.gas(2000000)();
  Assert.equal(r, false, "Transaction should fail, wrong leftPoint");

    //Make query with incorrect rightPoint
  PartitionInstantiator(address(aliceThrowProxy)).makeQuery(newIndex, queryPiece, partition.getQueryArrayAtIndex(newIndex, queryPiece ), 13); 
  
  partition.setState(newIndex, state.WaitingQuery);
    
  r = aliceThrowProxy.execute.gas(2000000)();
  Assert.equal(r, false, "Transaction should fail, wrong rightPoint");
  }
  
  //Test present divergence throws
  function testPresentDivergenceThrows() public {
    uint divergenceTime = 12;
    PartitionTestAux partition = PartitionTestAux(DeployedAddresses.PartitionTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(partition));
  uint newIndex = partition.instantiate(address(aliceThrowProxy),address(0x123),"initialHash","finalHash", 50000, 15, 55);   
    
    partition.setTimeSubmittedAtIndex(newIndex, divergenceTime + 1); 

    //Present divergencePoint after finalTime
    PartitionInstantiator(address(aliceThrowProxy)).presentDivergence(newIndex, 30); 
    
    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, divergence time >  final time");
 
    //Present non submitted divergencePoint
    PartitionInstantiator(address(aliceThrowProxy)).presentDivergence(newIndex, divergenceTime); 
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, divergence point was not submitted");


    //Present submitted divergencePoint  but divergencePoint + 1 not submitted
    divergenceTime += 1;
    PartitionInstantiator(address(aliceThrowProxy)).presentDivergence(newIndex, divergenceTime); 
    
    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, divergence point + 1 was not submitted");
  }
  // Test modifiers
  function testModifiers() public {
 
    //OnlyInstantiated 
    PartitionTestAux partition = PartitionTestAux(DeployedAddresses.PartitionTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(partition));
    
    uint newIndex = partition.instantiate(address(0x2123),address(0x193),"initialHash","finalHash", 50000, 15, 55);   
     partition.setState(newIndex, state.WaitingHashes);
 
    for(uint i = 0; i < 15; i++){
      replyArray[i] = "0123";
      postedTimes[i] = partition.getQueryArrayAtIndex(newIndex,i);
    }
    //ReplyArray with uninstantiated index
    uint wrongIndex = newIndex + 1;
    PartitionInstantiator(address(aliceThrowProxy)).replyQuery(wrongIndex, postedTimes, replyArray); 

    bool r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Transaction should fail, partition is not instantiated");
    //ReplyArray called by non claimer
    PartitionInstantiator(address(aliceThrowProxy)).replyQuery(newIndex, postedTimes, replyArray); 

    r = aliceThrowProxy.execute.gas(2000000)();
    Assert.equal(r, false, "Non claimer caller, transaction should fail");
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
  function() external{
    data = msg.data;
  }

  function execute() public returns (bool) {
    bool r;
    (r, ) = target.call(data);
    return r;
  }
}
