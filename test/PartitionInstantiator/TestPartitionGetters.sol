pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestPartitionGetters is PartitionInstantiator{
  
  address mockAddress = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;
   //arbitrary seeds to simulate initial and final hash
  uint initialHashSeed = 3;
  uint finalHashSeed = 4;
  
  function testDivergenceTime() public {
    uint newIndex = instantiate(msg.sender, mockAddress,bytes32(initialHashSeed),bytes32(finalHashSeed), 5000, 3, 55);
    uint newDivergenceTime = 5;
    instance[newIndex].divergenceTime = newDivergenceTime;

    Assert.equal(newDivergenceTime, divergenceTime(newIndex), "divergence time should be equal");

  }

  function testTimeSubmitted() public {
    uint newIndex = instantiate(msg.sender,mockAddress,bytes32(initialHashSeed),bytes32(finalHashSeed), 5000, 3, 55);
    uint key = 3;
    instance[newIndex].timeSubmitted[key] = true;

    Assert.equal(timeSubmitted(newIndex, key), true, "time submitted should be true");  
  }

  function testTimeHash() public {
    uint newIndex = instantiate(msg.sender,mockAddress,bytes32(initialHashSeed),bytes32(finalHashSeed), 5000, 3, 55);
    uint key = 3;
    instance[newIndex].timeHash[key] = bytes32(uint256(0x121));

    Assert.equal(timeHash(newIndex, key), bytes32(uint256(0x121)), "time hash should match");
  }

  function testQueryArray() public {
    uint newIndex = instantiate(msg.sender,mockAddress,bytes32(initialHashSeed),bytes32(finalHashSeed), 5000, 15, 55);
    for(uint i = 0; i < instance[newIndex].querySize; i++){
      Assert.equal(instance[newIndex].queryArray[i], queryArray(newIndex,i), "queryArray should match");
    }
  }
}

