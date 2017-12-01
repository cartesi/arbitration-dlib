// This is not the best way to do a bet between two players.
// For better bets, use something similar to RANDAO's algorithm.
// This should however be safe and more modular for other tasks.

/// @title Betting contract
pragma solidity ^0.4.0;

import "./partition.sol";
import "./timeaware.sol";

contract bet is timeAware {
  address public challenger;
  address public claimer;

  bytes32 public initialHash; // consensusual between challenger and claimer
  bytes32 public claimedFinalHash; // could be non-consensual
  uint public finalTime;

  uint public timeOfLastMove; // last time someone made a move with deadline
  uint public roundDuration; // time interval one has before expiration

  uint public challengeCost; // price to start a challenge

  partition public partitionContract;

  enum state { WaitingClaim, WaitingChallenge, WaitingResolution,
               ChallengerWon, ClaimerWon }

  state public currentState;

  event BetStarted(address theChallenger, address theClaimer,
                   bytes32 theInitialHash, uint theFinalTime,
                   uint theRoundDuration);
  event ClaimPosted(bytes32 theClaimedHash);
  event ChallengePosted(address thePartitionContract);
  event WinerFound(state finalState);

  function bet(address theChallenger, address theClaimer, uint theFinalTime,
               uint theRoundDuration, uint theChallengeCost) payable public {
    require(theChallenger != theClaimer);
    challenger = theChallenger;
    claimer = theClaimer;
    require(theFinalTime > 0);
    finalTime = theFinalTime;

    roundDuration = theRoundDuration;
    timeOfLastMove = getTime();

    initialHash = block.blockhash(block.number - 1);
    challengeCost = theChallengeCost;

    currentState = state.WaitingClaim;
    BetStarted(challenger, claimer, initialHash,
               finalTime, roundDuration);
  }

  function getPartitionCurrentState() view public returns (partition.state) {
    return partitionContract.currentState();
  }

  /// @notice Posts a claim (can only be called by claimer)
  /// @param theClaimedFinalHash the hash that is claimed to be the final
  function postClaim(bytes32 theClaimedFinalHash) public {
    require(msg.sender == claimer);
    require(currentState == state.WaitingClaim);
    claimedFinalHash = theClaimedFinalHash;
    currentState = state.WaitingChallenge;
    timeOfLastMove = getTime();
    ClaimPosted(claimedFinalHash);
  }

  /// @notice Post a challenge to claimed final hash (only challenger can do)
  function postChallenge() public payable {
    require(msg.sender == challenger);
    require(currentState == state.WaitingChallenge);
    //require(msg.value > challengeCost);
    // one needs to pay to post a challenge
    partitionContract = new partition(challenger, claimer,
                                      initialHash, claimedFinalHash,
                                      finalTime, 10, roundDuration);
    currentState = state.WaitingResolution;
    ChallengePosted(partitionContract);
  }

  /// @notice Claim victory (challenger only)
  function challengerClaimVictory() public {
    require(msg.sender == challenger);
    bool won = false;
    // claimer lost deadline to submit claim
    if (currentState == state.WaitingClaim
        && getTime() > timeOfLastMove + roundDuration) {
      won = true;
    }
    // the claimed number is even (challenger's luck)
    if (currentState == state.WaitingChallenge
        && uint(claimedFinalHash) % 2 == 0) {
      won = true;
    }
    // challenger won the partition challenge (claimer misses deadline there)
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.ChallengerWon) {
      won = true;
    }
    // partition challenge ended in divergence and challenger won divergence
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.DivergenceFound) {
      bytes32 beforeDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime());
      bytes32 afterDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime() + 1);
      if (keccak256(beforeDivergence) != afterDivergence) {
        won = true;
      }
    }
    if (won) {
      currentState = state.ChallengerWon;
      WinerFound(currentState);
      selfdestruct(challenger);
    }
  }

  /// @notice Claim victory (claimer only)
  function claimerClaimVictory() public {
    require(msg.sender == claimer);
    bool won = false;
    // timeout to submit challenge
    if (currentState == state.WaitingChallenge
        && getTime() > timeOfLastMove + roundDuration) {
      won = true;
    }
    // claimer won the partition challenge
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.ClaimerWon) {
      won = true;
    }
    // partition challenge ended in divergence and claimer won divergence
    if (currentState == state.WaitingResolution
        && getPartitionCurrentState() == partition.state.DivergenceFound) {
      bytes32 beforeDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime());
      bytes32 afterDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime() + 1);
      if (keccak256(beforeDivergence) == afterDivergence) {
        won = true;
      }
    }
    if (won) {
      currentState = state.ClaimerWon;
      WinerFound(currentState);
      selfdestruct(claimer);
    }
  }
}

