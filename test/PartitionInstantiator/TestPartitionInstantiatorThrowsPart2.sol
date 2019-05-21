pragma solidity 0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";
import "../../contracts/testAuxiliaries/PartitionTestAux.sol";

contract TestPartitionInstantiatorThrowsPart2 is PartitionInstantiator{
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  bytes32[] wrongReplyArray = new bytes32[](3);
  uint256[] wrongPostedTimes = new uint[](3);

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
