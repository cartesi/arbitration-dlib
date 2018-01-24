/// @title Partition contract
pragma solidity ^0.4.18;

contract mortal {
  address public owner;

  function mortal() public {
    owner = msg.sender;
  }

  function kill() public {
    if (msg.sender == owner) selfdestruct(owner);
  }
}


contract depth is mortal {
  address public challenger;
  address public claimer;

  uint public timeOfLastMove;
  uint public roundDuration;

  bytes32 public claimerLeftChildHash;
  bytes32 public claimerRightChildHash;
  bytes32 public claimerCurrentHash;
  bytes32 public currentDepth;

  bytes32 public controvertialHashOfClaimer;

  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon,
               WaitingPostControvertial, Finished }
  state public currentState;

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  event ChallengeEnded(state theState);
  event DivergenceFound(uint64 addressStartingDivergence,
                        bytes32 theControversialHashOfClaimer);

  //            Query
  //              |
  //            Hashes (0 to 1)
  //              |
  //             ...
  //              |
  //            Hashes (58 to 59)
  //              |
  //            Query
  //              |
  //            PostControv
  //              |
  //            Finished

  function depth(address theChallenger, address theClaimer,
                 bytes32 theClaimerHashOfRoot,
                 uint theRoundDuration) public
  {
    require(theChallenger != theClaimer);
    challenger = theChallenger;
    claimer = theClaimer;
    claimerCurrentHash = theClaimerHashOfRoot;
    currentDepth = 0;

    roundDuration = theRoundDuration;
    timeOfLastMove = now;

    currentState = state.WaitingHashes;
    QueryPosted(queryArray);
  }

  /// @notice Answer the query (only claimer can call it).
  /// @param leftHash the hash to the left of the current one.
  /// @param rightHash the hash to the right of the current one.
  function replyQuery(bytes32 leftHash, bytes32 rightHash) public {
    require(msg.sender == claimer);
    require(currentState == state.WaitingHashes);
    require(keccak256(leftHash, rightHash) == claimerCurrentHash);
    claimerLeftChildHash = leftHash;
    claimerRightChildHash = leftHash;
    currentState = state.WaitingQuery;
    timeOfLastMove = now;
    HashesPosted(postedTimes, postedHashes);
  }

  /// @notice Makes a query (only challenger can call it).
  /// @param continueToTheLeft a boolean saying if we should continue to the
  /// left (otherwise we continue to the right)
  function makeQuery(bool continueToTheLeft) public {
    require(msg.sender == challenger);
    require(currentState == state.WaitingQuery);

    if(continueToTheLeft) {
      claimerCurrentHash = claimerLeftChildHash;
    } else {
      claimerCurrentHash = claimerRigthChildHash;
    }
    currentDepth = currentDepth + 1;
    if (currentDepth < 59) {
      currentState = state.WaitingHashes;
    } else {
      currentState = state.WaitingPostControvertial;
    }
    timeOfLastMove = now;
    QueryPosted(queryArray);
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime() public {
    if ((msg.sender == challenger) && (currentState == state.WaitingHashes)
        && (now > timeOfLastMove + roundDuration)) {
      currentState = state.ChallengerWon;
      ChallengeEnded(currentState);
    }
    if ((msg.sender == claimer) && (currentState == state.WaitingQuery)
        && (now > timeOfLastMove + roundDuration)) {
      currentState = state.ClaimerWon;
      ChallengeEnded(currentState);
    }
  }

  /// @notice Present a precise time of divergence (can only be called by
  /// challenger).
  /// @param theDivergenceTime The time when the divergence happended. It
  /// should be a point of aggreement, while theDivergenceTime + 1 should be a
  /// point of disagreement (both queried).
  function presentDivergence(uint theDivergenceTime) public {
    require(msg.sender == challenger);
    require(theDivergenceTime < finalTime);
    require(timeSubmitted[theDivergenceTime]);
    require(timeSubmitted[theDivergenceTime + 1]);
    divergenceTime = theDivergenceTime;
    currentState = state.DivergenceFound;
    ChallengeEnded(currentState);
    DivergenceFound(theDivergenceTime, timeHash[theDivergenceTime],
                    timeHash[theDivergenceTime + 1]);
  }
}

