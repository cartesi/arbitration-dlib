pragma solidity ^0.4.18;

import "ds-test/test.sol";
import "./partition.sol";

contract timedPartition is partition {
  uint extraTime;

  function timedPartition(address theChallenger, address theClaimer,
                     bytes32 theInitialHash, bytes32 theClaimerFinalHash,
                     uint theFinalTime, uint theQuerySize,
                     uint theRoundDuration)
    partition(theChallenger, theClaimer, theInitialHash, theClaimerFinalHash,
                      theFinalTime, theQuerySize, theRoundDuration) public {
    extraTime = 0;
  }
  function fastForward(uint timeChange) public {
    extraTime += timeChange;
  }
  function getTime() view internal returns (uint) {
  return now + extraTime;
  }
}

contract User {

  function User() public {
  }
  function replyQuery(partition partitionContract,
                      uint[] postedTimes, bytes32[] postedHashes) public {
    partitionContract.replyQuery(postedTimes, postedHashes);
  }
  function makeQuery(partition partitionContract,
                     uint queryPiece, uint leftPoint, uint rightPoint) public {
    partitionContract.makeQuery(queryPiece, leftPoint, rightPoint);
  }
  function claimVictoryByTime(partition partitionContract) public {
    partitionContract.claimVictoryByTime();
  }
  function presentDivergence(partition partitionContract,
                             uint theDivergenceTime) public {
    partitionContract.presentDivergence(theDivergenceTime);
  }
}

contract PartitionTest is DSTest {

  timedPartition partitionContract;
  User alice;
  User bob;

  bytes32 initialHash;
  bytes32[] aliceHistory;
  bytes32[] bobHistory;
  bytes32 aliceFinalHash;
  bytes32 bobFinalHash;

  uint256[] queryArray;
  bytes32[] bobAnswer;

  uint lastTime;
  uint lastAggreement;

  event MyEvent(string message);

  function setUp() public {
    alice = new User();
    bob = new User();
    // preparing alice and bob hashes
    initialHash = keccak256('i');
    aliceFinalHash = initialHash;
    bobFinalHash = initialHash;

    uint i;
    lastTime = 2000;
    lastAggreement = 1234;

    for (i = 0; i < lastTime + 1; i++) {
      aliceHistory.push(aliceFinalHash);
      bobHistory.push(bobFinalHash);
      aliceFinalHash = keccak256(aliceFinalHash);
      bobFinalHash = keccak256(bobFinalHash);
      if (i == lastAggreement) { bobFinalHash = keccak256('error'); }
    }
    partitionContract = new timedPartition(alice, bob, initialHash, bobFinalHash,
                                           lastTime, 5, 3600);

    // initialize empty query array
    for (i = 0; i < partitionContract.querySize(); i++) {
      queryArray.push(0);
      bobAnswer.push(keccak256(''));
    }
  }

  function test_divergence() public {
    uint i;
    while(true) {
      // now waiting hashes, bob prepares and posts them
      assert(partitionContract.currentState() == partition.state.WaitingHashes);
      for (i = 0; i < partitionContract.querySize(); i++) {
        queryArray[i] = partitionContract.queryArray(i);
        bobAnswer[i] = bobHistory[queryArray[i]];
      }
      bob.replyQuery(partitionContract, queryArray, bobAnswer);

      // now wait query, alice finds the interval of disagreement
      uint lastConsensualQuery = 0;
      assert(partitionContract.currentState() == partition.state.WaitingQuery);
      for (i = 0; i < partitionContract.querySize() - 1; i++) {
        assert(partitionContract.timeSubmitted(partitionContract.queryArray(i)));
        if (aliceHistory[partitionContract.queryArray(i)]
            == partitionContract.timeHash(partitionContract.queryArray(i))) {
          lastConsensualQuery = i;
        } else {
          break;
        }
      }
      uint leftPoint = partitionContract.queryArray(lastConsensualQuery);
      uint rightPoint = partitionContract.queryArray(lastConsensualQuery + 1);

      // sees if the interval is unitary
      if (rightPoint != leftPoint + 1) {
        // if the interval is not unitary, make query with interval
        alice.makeQuery(partitionContract, lastConsensualQuery,
                        leftPoint, rightPoint);
      } else {
        // otherwise, present divergence
        alice.presentDivergence(partitionContract, leftPoint);
        assertEq(partitionContract.divergenceTime(), lastAggreement);
        break;
      }
    }
  }

  function testFail_claimer_does_not_timeout() public {
    // now waiting hashes, bob prepares and posts them
    assert(partitionContract.currentState() == partition.state.WaitingHashes);
    partitionContract.fastForward(3500);
    alice.claimVictoryByTime(partitionContract);
    assert(partitionContract.currentState() == partition.state.ChallengerWon);
  }

  function test_claimer_timeout() public {
    // now waiting hashes, bob prepares and posts them
    assert(partitionContract.currentState() == partition.state.WaitingHashes);
    partitionContract.fastForward(3601);
    alice.claimVictoryByTime(partitionContract);
    assert(partitionContract.currentState() == partition.state.ChallengerWon);
  }



}
