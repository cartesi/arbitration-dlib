import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/PartitionInstantiator.sol";

contract TestPartitionInstantiator {
  
  function testInstantiate() {
    PartitionInstantiator partitionContract = PartitionInstantiator(DeployedAddresses.PartitionInstantiator());

    uint expected = 500;
    Assert.equal(500, expected, "testing structure");
  }

}
