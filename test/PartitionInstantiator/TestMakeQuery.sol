pragma solidity 0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/PartitionInstantiator.sol";

contract TestMakeQuery is PartitionInstantiator{
  uint nextIndex = 0;
  address mockAddress = 0x0014060Ff383C9B21C6840A3b14AAb06741E5c49;

  function testMakeQuery() public {
    uint newIndex;
    uint queryPiece;
    uint leftPoint;
    uint rightPoint;

    //arbitrary seeds to simulate initial and final hash
    uint initialHashSeed = 3;
    uint finalHashSeed = 4;

    for(uint i = 1; i < 5; i++) {
      newIndex = instantiate(msg.sender,mockAddress, bytes32(i + initialHashSeed), bytes32(i + finalHashSeed), 5000 * i, i * 3, i * 55);
      queryPiece = instance[newIndex].querySize - 2;
      leftPoint  = instance[newIndex].queryArray[queryPiece];
      rightPoint = instance[newIndex].queryArray[queryPiece + 1];
      instance[newIndex].currentState = state.WaitingQuery;
      makeQuery(newIndex, queryPiece, leftPoint, rightPoint);

      Assert.equal(uint(instance[newIndex].currentState), uint(state.WaitingHashes), "State should be waiting hashes");
      Assert.equal(instance[newIndex].timeOfLastMove, now, "time of last move should be now");
    }
  }
}
