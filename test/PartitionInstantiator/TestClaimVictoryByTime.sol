pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestClaimVictoryByTime is PartitionInstantiator{
  uint nextIndex = 0;
  
  address mockAddress = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;
  
  //arbitrary seeds to simulate initial and final hash
  uint initialHashSeed = 3;
  uint finalHashSeed = 4;
 
  function testClaimVictoryByTime() public {
    uint newIndex;
    for (uint i = 1;i < 6; i++){
      //alternate between msg.sender being challenger and claimer
      if(i % 2 == 0){
        newIndex = instantiate(msg.sender, mockAddress, bytes32(initialHashSeed + i), bytes32(finalHashSeed + i), 5000 * i, 3 * i, 55 * i);
        instance[newIndex].currentState = state.WaitingHashes;
      }else{
        newIndex = instantiate(mockAddress, msg.sender,bytes32(initialHashSeed + i), bytes32(finalHashSeed + i), 5000 * i, 3 * i, 55 * i);
        instance[newIndex].currentState = state.WaitingQuery;
      } 
      //Setting round duration and timeOfLastMove to zero to bypass modifiers (simulate player ran out of time to answer)   
      instance[newIndex].timeOfLastMove = 0; 
      instance[newIndex].roundDuration = 0;

      claimVictoryByTime(newIndex);
      Assert.equal(uint(instance[newIndex].currentState), i%2 == 0? uint(state.ChallengerWon):uint(state.ClaimerWon), "State should be waiting hashes");
    }
  }
}

