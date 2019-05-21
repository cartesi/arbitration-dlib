pragma solidity 0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";
import "../../contracts/testAuxiliaries/PartitionTestAux.sol";

contract TestPartitionInstantiatorThrowsPart4 is PartitionInstantiator{
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  bytes32[] wrongReplyArray = new bytes32[](3);
  uint256[] wrongPostedTimes = new uint[](3);

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
