/// @title Betting contract
pragma solidity ^0.4.0;

import "./partition.sol"

contract bet {
  address public challenger;
  address public claimer;

  bytes32 initialHash;
  bytes32 claimedFinalHash;

  uint public finalTime;
  uint public roundDuration;

  address partitionContract;

  enum state { WaitingClaim, WaitingChallenge, WaitingResolution,
               ChallengerWon, ClaimerWon }

  state public currentState;

  event BetStarted(address theChallenger, address theClaimer,
                   uint theFinalTime, uint theRoundDuration)
  event ClaimPosted(bytes32 theClaimedHash);
  event ChallengePosted(address thePartitionContract);
  event WinerFound(state finalState);

  function bet(address theChallenger, address theClaimer,
               uint theFinalTime, uint theRoundDuration) public {
    require(theChallenger != theClaimer);
    challenger = theChallenger;
    claimer = theClaimer;
    require(theFinalTime > 0);
    finalTime = theFinalTime;

    initialHash = block.blockhash(block.number - 1);

    roundDuration = theRoundDuration;
    timeOfLastMove = now;

    currentState = state.WaitingClaim;
    BetStarted(address theChallenger, address theClaimer,
               uint theFinalTime, uint theRoundDuration)
  }

  /// @notice Posts a claim (can only be called by claimer)
  /// @param claimedFinalHash the hash that is inteded to be claimed as final
  function postClaim(bytes32 theClaimedFinalHash) public {
    require(msg.sender == claimer);
    require(currentState == state.WaitingClaim);
    claimedFinalHash = theClaimedFinalHash
    currentState = state.WaitingChallenge;
    timeOfLastMove = now;
    ClaimPosted(theClaimedFinalHash);
  }

  /// @notice Post a challenge to claimed final hash (only challenger can do)
  function postChallenge() public {
    require(msg.sender == challenger);
    require(currentState == state.WaitingChallenge);
    prtitionContract = new partition(challenger, claimer,
                                     initialHash, claimedFinalHash,
                                     finalTime, 10, roundDuration);
    currentState = state.WaitingResolution;
    ChallengePosted(partitionContract);
  }

  /// @notice Challenger claims victory
  function challengerClaimVictory() public {
    require(msg.sender == challenger);
    // timeout to submit claim
    if (currentState == state.WaitingClaim
        && now > timeOfLastMove + roundDuration) {
      currentState = state.ChallengerWon;
      WinerFound(currentState);
      selfdestruct(challenger);
    }
    // challenger won the partition challenge
    if (currentState == state.WaitingResolution
        && partitionContract.state == partitionContract.state.ChallengerWon) {
      currentState = state.ChallengerWon;
      WinerFound(currentState);
      selfdestruct(challenger);
    }
    // partition challenge ended in divergence and challenger won divergence
    if (currentState == state.WaitingResolution
        && partitionContract.state == partitionContract.state.DivergenceFound) {
      bytes32 beforeDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime());
      bytes32 afterDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime() + 1);
      if (sha3(beforeDivergence) != sha3(afterDivergence)) {
        currentState = state.ChallengerWon;
        WinerFound(currentState);
        selfdestruct(challenger);
      }
    }
  }

  /// @notice Claimer claims victory
  function claimerClaimVictory() public {
    require(msg.sender == claimer);
    // timeout to submit challenge
    if (currentState == state.WaitingChallenge
        && now > timeOfLastMove + roundDuration) {
      currentState = state.ClaimerWon;
      WinerFound(currentState);
      selfdestruct(claimer);
    }
    // claimer won the partition challenge
    if (currentState == state.WaitingResolution
        && partitionContract.state == partitionContract.state.ClaimerWon) {
      currentState = state.ClaimerWon;
      WinerFound(currentState);
      selfdestruct(claimer);
    }
    // partition challenge ended in divergence and claimer won divergence
    if (currentState == state.WaitingResolution
        && partitionContract.state == partitionContract.state.DivergenceFound) {
      bytes32 beforeDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime());
      bytes32 afterDivergence = partitionContract
        .timeHash(partitionContract.divergenceTime() + 1);
      if (sha3(beforeDivergence) == sha3(afterDivergence)) {
        currentState = state.ClaimerWon;
        WinerFound(currentState);
        selfdestruct(claimer);
      }
    }
  }
}

