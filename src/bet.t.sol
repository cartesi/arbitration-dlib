pragma solidity ^0.4.18;

import "ds-test/test.sol";
import "./partition.sol";
import "./bet.sol";

contract testBet is bet {
  uint extraTime;

  // this class allows us to override the getPartitionCurrentState() method,
  // allowing us to artificially set a different state for testing purposes
  bool hasArtificialPartitionState;
  partition.state artificialPartitionState;

  function testBet(address theChallenger, address theClaimer,
                    uint theFinalTime, uint theRoundDuration,
                    uint theChallengeCost)
    bet(theChallenger, theClaimer, theFinalTime, theRoundDuration,
        theChallengeCost) public {
    extraTime = 0;
  }
  function setPartitionCurrentState(partition.state newState) public {
    hasArtificialPartitionState = true;
    artificialPartitionState = newState;
  }
  function getPartitionCurrentState() view public returns (partition.state) {
    if (hasArtificialPartitionState) {
      return artificialPartitionState;
    } else {
      return partitionContract.currentState();
    }
  }
  function setInitialHash(bytes32 theInitialHash) public {
    initialHash = theInitialHash;
  }
  function fastForward(uint timeChange) public {
    extraTime += timeChange;
  }
  function getTime() view internal returns (uint) {
  return now + extraTime;
  }
}

contract User is DSTest {

  // bet contract interaction
  function User() public {
  }
  function () public payable {}
  function postClaim(bet betContract,
                     bytes32 theClaimedFinalHash) public {
    betContract.postClaim(theClaimedFinalHash);
  }
  function postChallenge(bet betContract, uint valueSent) public {
    betContract.postChallenge.value(valueSent)();
  }
  function challengerClaimVictory(bet betContract) public {
    betContract.challengerClaimVictory();
  }
  function claimerClaimVictory(bet betContract) public {
    betContract.claimerClaimVictory();
  }

  // partition contract interaction
  function replyQuery(partition partitionContract,
                      uint[] postedTimes, bytes32[] postedHashes) public {
    partitionContract.replyQuery(postedTimes, postedHashes);
  }
  function makeQuery(partition partitionContract,
                     uint queryPiece, uint leftPoint, uint rightPoint) public {
    partitionContract.makeQuery(queryPiece, leftPoint, rightPoint);
  }
  function presentDivergence(partition partitionContract,
                             uint theDivergenceTime) public {
    partitionContract.presentDivergence(theDivergenceTime);
  }
}

contract BetTest is DSTest {

  testBet betContract;
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
    alice.transfer(1 ether);
    bob = new User();

    lastTime = 2000;

    betContract = new testBet(alice, bob, lastTime, 3600, 10 finney);
  }

  function prepareHistory() private {
    initialHash = betContract.initialHash();

    aliceFinalHash = initialHash;
    bobFinalHash = initialHash;

    for (uint i = 0; i < lastTime + 1; i++) {
      aliceHistory.push(aliceFinalHash);
      bobHistory.push(bobFinalHash);
      aliceFinalHash = keccak256(aliceFinalHash);
      bobFinalHash = keccak256(bobFinalHash);
      if (i == lastAggreement) { bobFinalHash = keccak256('error'); }
    }
  }

  function test_true_divergence() public {
    lastAggreement = 1234;
    prepareHistory();

    // bob posts a claim
    bob.postClaim(betContract, bobHistory[lastTime]);
    assert(betContract.claimedFinalHash() != aliceHistory[lastTime]);

    // alice challenges the claim
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    alice.postChallenge(betContract, 200 finney);
    partition partitionContract = betContract.partitionContract();

    uint i;
    // initialize empty query array
    for (i = 0; i < partitionContract.querySize(); i++) {
      queryArray.push(0);
      bobAnswer.push(keccak256(''));
    }

    while(true) {
      // now waiting hashes, bob prepares and posts them
      assert(betContract.getPartitionCurrentState()
             == partition.state.WaitingHashes);
      for (i = 0; i < partitionContract.querySize(); i++) {
        queryArray[i] = partitionContract.queryArray(i);
        bobAnswer[i] = bobHistory[queryArray[i]];
      }
      bob.replyQuery(partitionContract, queryArray, bobAnswer);

      // now wait query, alice finds the interval of disagreement
      uint lastConsensualQuery = 0;
      assert(betContract.getPartitionCurrentState()
             == partition.state.WaitingQuery);
      for (i = 0; i < partitionContract.querySize() - 1; i++) {
        assert(partitionContract
               .timeSubmitted(partitionContract.queryArray(i)));
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
        // if the interval is not unitary, send query with interval
        alice.makeQuery(partitionContract, lastConsensualQuery,
                        leftPoint, rightPoint);
      } else {
        // otherwise, present divergence
        alice.presentDivergence(partitionContract, leftPoint);
        assert(partitionContract.divergenceTime() == lastAggreement);
        break;
      }
    }
    alice.challengerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.ChallengerWon);
  }

  function test_fake_divergence() public {
    lastAggreement = 3000; // this gives a full agreement (3000 > 2000)
    prepareHistory();

    // bob posts a claim
    bob.postClaim(betContract, bobHistory[lastTime]);
    assert(betContract.claimedFinalHash() == aliceHistory[lastTime]);

    // alice challenges the claim
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    alice.postChallenge(betContract, 200 finney);
    partition partitionContract = betContract.partitionContract();

    uint i;
    // initialize empty query array
    for (i = 0; i < partitionContract.querySize(); i++) {
      queryArray.push(0);
      bobAnswer.push(keccak256(''));
    }

    while(true) {
      // now waiting hashes, bob prepares and posts them
      assert(betContract.getPartitionCurrentState()
             == partition.state.WaitingHashes);
      for (i = 0; i < partitionContract.querySize(); i++) {
        queryArray[i] = partitionContract.queryArray(i);
        bobAnswer[i] = bobHistory[queryArray[i]];
      }
      bob.replyQuery(partitionContract, queryArray, bobAnswer);

      // now wait query, alice has not divergence interval to present
      // so she presents always the first one
      uint lastConsensualQuery = 0;

      uint leftPoint = partitionContract.queryArray(lastConsensualQuery);
      uint rightPoint = partitionContract.queryArray(lastConsensualQuery + 1);

      // sees if the interval is unitary
      if (rightPoint != leftPoint + 1) {
        // if the interval is not unitary, send query with interval
        alice.makeQuery(partitionContract, lastConsensualQuery,
                        leftPoint, rightPoint);
      } else {
        // otherwise, present divergence
        alice.presentDivergence(partitionContract, leftPoint);
        break;
      }
    }
    bob.claimerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.ClaimerWon);
  }

  function test_alice_luck() public {
    // preparing alice and bob hashes
    initialHash = betContract.initialHash();
    betContract.setInitialHash("A"); // iterating this makes alice win

    // preparing alice and bob hashes
    lastAggreement = lastTime + 1; // no disagreement
    prepareHistory();

    // bob posts a claim
    assert(betContract.currentState() == bet.state.WaitingClaim);
    bob.postClaim(betContract, bobFinalHash);
    assert(betContract.claimedFinalHash() == aliceFinalHash);

    // alice claims victory
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    alice.challengerClaimVictory(betContract);

    // alice won
    assert(betContract.currentState() == bet.state.ChallengerWon);
  }

  function test_bob_timeout() public {
    betContract.setInitialHash("AAAA"); // iterating this, bob wins
    // preparing alice and bob hashes
    lastAggreement = lastTime + 1; // no disagreement
    prepareHistory();

    betContract.fastForward(3500);

    // alice cannot claim victory yet
    assert(betContract.currentState() == bet.state.WaitingClaim);
    alice.challengerClaimVictory(betContract);
    // it fails...
    assert(betContract.currentState() == bet.state.WaitingClaim);

    betContract.fastForward(200);

    // alice can claim victory now
    alice.challengerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.ChallengerWon);
  }

  function test_alice_timeout() public {
    betContract.setInitialHash("AAAA"); // iterating this, bob wins
    // preparing alice and bob hashes
    lastAggreement = lastTime + 1; // no disagreement
    prepareHistory();

    // bob posts a claim
    assert(betContract.currentState() == bet.state.WaitingClaim);
    bob.postClaim(betContract, bobFinalHash);
    assert(betContract.claimedFinalHash() == aliceFinalHash);

    betContract.fastForward(3500);

    // bob cannot claim victory yet
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    bob.claimerClaimVictory(betContract);
    // it fails...
    assert(betContract.currentState() == bet.state.WaitingChallenge);

    betContract.fastForward(200);

    // bob can claim victory now
    bob.claimerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.ClaimerWon);
  }

  function test_bob_lost_in_partition() public {
    betContract.setInitialHash("AAAA"); // iterating this, bob wins
    // preparing alice and bob hashes
    lastAggreement = lastTime + 1; // no disagreement
    prepareHistory();

    // bob posts a claim
    assert(betContract.currentState() == bet.state.WaitingClaim);
    bob.postClaim(betContract, bobFinalHash);
    assert(betContract.claimedFinalHash() == aliceFinalHash);

    // alice challenges the claim
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    alice.postChallenge(betContract, 200 finney);
    //timedPartition partitionContract = betContract.partitionContract();

    // alice cannot claim victory yet
    assert(betContract.currentState() == bet.state.WaitingResolution);
    alice.challengerClaimVictory(betContract);
    // it fails...
    assert(betContract.currentState() == bet.state.WaitingResolution);

    betContract.setPartitionCurrentState(partition.state.ChallengerWon);

    // alice can claim victory now
    alice.challengerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.ChallengerWon);
  }

  function test_alice_lost_in_partition() public {
    betContract.setInitialHash("AAAA"); // iterating this, bob wins
    // preparing alice and bob hashes
    lastAggreement = lastTime + 1; // no disagreement
    prepareHistory();

    // bob posts a claim
    assert(betContract.currentState() == bet.state.WaitingClaim);
    bob.postClaim(betContract, bobFinalHash);
    assert(betContract.claimedFinalHash() == aliceFinalHash);

    // alice challenges the claim
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    alice.postChallenge(betContract, 200 finney);
    //timedPartition partitionContract = betContract.partitionContract();

    // bob cannot claim victory yet
    assert(betContract.currentState() == bet.state.WaitingResolution);
    bob.claimerClaimVictory(betContract);
    // it fails...
    assert(betContract.currentState() == bet.state.WaitingResolution);

    betContract.setPartitionCurrentState(partition.state.ClaimerWon);

    // bob can claim victory now
    bob.claimerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.ClaimerWon);
  }

  function test_alice_unluck() public {
    betContract.setInitialHash("AAAA"); // iterating this, bob wins
    // preparing alice and bob hashes
    lastAggreement = lastTime + 1; // no disagreement
    prepareHistory();

    // bob posts a claim
    assert(betContract.currentState() == bet.state.WaitingClaim);
    bob.postClaim(betContract, bobFinalHash);
    assert(betContract.claimedFinalHash() == aliceFinalHash);

    // alice cannot claim victory
    assert(betContract.currentState() == bet.state.WaitingChallenge);
    alice.challengerClaimVictory(betContract);
    assert(betContract.currentState() == bet.state.WaitingChallenge);

  }
}
