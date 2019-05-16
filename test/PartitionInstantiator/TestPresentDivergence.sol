pragma solidity 0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestPresentDivergence is PartitionInstantiator{
  address mockAddress = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;
  
  //arbitrary seeds to simulate initial and final hash
  uint initialHashSeed = 3;
  uint finalHashSeed = 4;
 
  function testPresentDivergence() public {
    uint newIndex;
    uint divergenceTime;
    for(uint i = 1; i < 7; i++){
      newIndex = instantiate(msg.sender, mockAddress,bytes32(i+initialHashSeed), bytes32(i + finalHashSeed), 5000 * i, 3 * i, 55 * i);       
      divergenceTime = instance[newIndex].finalTime - i;
      instance[newIndex].timeSubmitted[divergenceTime] = true;
      instance[newIndex].timeSubmitted[divergenceTime + 1] = true;
      presentDivergence(newIndex, divergenceTime);

      Assert.equal(uint(instance[newIndex].currentState), uint(state.DivergenceFound), "State should be divergence found");
    }
  }
}


