pragma solidity 0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";
import "../../contracts/PartitionTestAux.sol";

contract TestPartitionInstantiatorThrows is PartitionInstantiator{
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  bytes32[] wrongReplyArray = new bytes32[](3);
  uint256[] wrongPostedTimes = new uint[](3);
  
  //Test throws/requires
  function testReplyThrows() public { 
    PartitionTestAux partition = PartitionTestAux(DeployedAddresses.PartitionTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(partition));
    uint newIndex = partition.instantiate(0x2123,address(aliceThrowProxy),"initialHash","finalHash", 50000, 15, 55);   
      
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

  // Test modifiers
  function testModifiers() public {
 
    //OnlyInstantiated 
    PartitionTestAux partition = PartitionTestAux(DeployedAddresses.PartitionTestAux());
    ThrowProxy aliceThrowProxy = new ThrowProxy(address(partition));
    
    uint newIndex = partition.instantiate(0x2123,0x193,"initialHash","finalHash", 50000, 15, 55);   
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
