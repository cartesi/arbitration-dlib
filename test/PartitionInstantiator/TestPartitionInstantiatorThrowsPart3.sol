pragma solidity 0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";
import "../../contracts/testAuxiliaries/PartitionTestAux.sol";

contract TestPartitionInstantiatorThrowsPart3 is PartitionInstantiator{
  bytes32[] replyArray = new bytes32[](15);
  uint256[] postedTimes = new uint[](15);
  
  bytes32[] wrongReplyArray = new bytes32[](3);
  uint256[] wrongPostedTimes = new uint[](3);

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
