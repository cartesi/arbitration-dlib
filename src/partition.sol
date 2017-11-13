/// @title Partition contract
pragma solidity ^0.4.18;

import "./timeaware.sol";

contract mortal {
    address public owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract partition is mortal, timeAware {
  address public challenger;
  address public claimer;
  uint public finalTime; // hashes provided between 0 and finalTime (inclusive)

  mapping(uint => bool) public timeSubmitted; // marks a time as submitted
  mapping(uint => bytes32) public timeHash; // hashes are signed by claimer

  uint public querySize;
  uint[] public queryArray;

  uint public timeOfLastMove;
  uint public roundDuration;

  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon, DivergenceFound }
  state public currentState;

  uint public divergenceTime;

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  event ChallengeEnded(state theState);
  event DivergenceFound(uint timeOfDivergence, bytes32 hashAtDivergenceTime,
                        bytes32 hashRigthAfterDivergenceTime);

  function partition(address theChallenger, address theClaimer,
                     bytes32 theInitialHash, bytes32 theClaimerFinalHash,
                     uint theFinalTime, uint theQuerySize,
                     uint theRoundDuration) public {
    require(theChallenger != theClaimer);
    challenger = theChallenger;
    claimer = theClaimer;
    require(theFinalTime > 0);
    finalTime = theFinalTime;

    timeSubmitted[0] = true;
    timeSubmitted[finalTime] = true;
    timeHash[0] = theInitialHash;
    timeHash[finalTime] = theClaimerFinalHash;

    require(theQuerySize > 2);
    require(theQuerySize < 100);
    querySize = theQuerySize;
    for (uint i = 0; i < querySize; i++) { queryArray.push(0); }

    // slice the interval, placing the separators in queryArray
    slice(0, finalTime);

    roundDuration = theRoundDuration;
    timeOfLastMove = getTime();

    currentState = state.WaitingHashes;
    QueryPosted(queryArray);
  }

  // split an interval using (querySize) points (placed in queryArray)
  // leftPoint rightPoint are always the first and last points in queryArray.
  function slice(uint leftPoint, uint rightPoint) internal {
    require(rightPoint > leftPoint);
    uint i;
    uint intervalLength = rightPoint - leftPoint;
    // if intervalLength is not big enough to allow us jump sizes larger then
    // one, we go step by step
    if (intervalLength < 2 * (querySize - 1)) {
      for (i = 0; i < querySize - 1; i++) {
        if (leftPoint + i < rightPoint)
          { queryArray[i] = leftPoint + i; }
        else
          { queryArray[i] = rightPoint; }
      }
    } else {
      // otherwise: intervalLength = (querySize - 1) * divisionLength + j
      // with divisionLength >= 1 and j in {0, ..., querySize - 2}. in this
      // case the size of maximum slice drops to a proportion of intervalLength
      uint divisionLength = intervalLength / (querySize - 1);
      for (i = 0; i < querySize - 1; i++) {
        queryArray[i] = leftPoint + i * divisionLength;
      }
    }
    queryArray[querySize - 1] = rightPoint;
  }

  /// @notice Answer the query (only claimer can call it).
  /// @param postedTimes An array (of size querySize) with the times that have been queried.
  /// @param postedHashes An array (of size querySize) with the hashes corresponding to the queried times
  function replyQuery(uint[] postedTimes, bytes32[] postedHashes) public {
    require(msg.sender == claimer);
    require(currentState == state.WaitingHashes);
    require(postedTimes.length == querySize);
    require(postedHashes.length == querySize);
    for (uint i = 0; i < querySize; i++) {
      // make sure the claimer knows the current query
      require(postedTimes[i] == queryArray[i]);
      // cannot rewrite previous answer
      if (!timeSubmitted[postedTimes[i]]) {
        timeSubmitted[postedTimes[i]] = true;
        timeHash[postedTimes[i]] = postedHashes[i];
      }
    }
    currentState = state.WaitingQuery;
    timeOfLastMove = getTime();
    HashesPosted(postedTimes, postedHashes);
  }

  /// @notice Makes a query (only challenger can call it).
  /// @param queryPiece is the index of queryArray corresponding to the left limit of the next interval to be queried.
  /// @param leftPoint confirmation of the leftPoint of the interval to be split. Should be an aggreement point.
  /// @param leftPoint confirmation of the rightPoint of the interval to be split. Should be a disagreement point.
  function makeQuery(uint queryPiece, uint leftPoint, uint rightPoint) public {
    require(msg.sender == challenger);
    require(currentState == state.WaitingQuery);
    require(queryPiece < querySize - 1);
    // make sure the challenger knows the previous query
    require(leftPoint == queryArray[queryPiece]);
    require(rightPoint == queryArray[queryPiece + 1]);
    // no unitary queries. in unitary case, present divergence instead.
    // by avoiding unitary queries one forces the contest to end
    require(rightPoint - leftPoint > 1);
    slice(leftPoint, rightPoint);
    currentState = state.WaitingHashes;
    timeOfLastMove = getTime();
    QueryPosted(queryArray);
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime() public {
    if (msg.sender == challenger && currentState == state.WaitingHashes
        && getTime() > timeOfLastMove + roundDuration)
      { currentState = state.ChallengerWon;
        ChallengeEnded(currentState);
      }
    if (msg.sender == claimer && currentState == state.WaitingQuery
        && getTime() > timeOfLastMove + roundDuration)
      { currentState = state.ClaimerWon;
        ChallengeEnded(currentState);
      }
  }

  /// @notice Present a precise time of divergence (can only be called by challenger).
  /// @param theDivergenceTime The time when the divergence happended. It should be a point of aggreement, while theDivergenceTime + 1 should be a point of disagreement (both queried).
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

