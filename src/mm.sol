/// @title Partition contract
pragma solidity ^0.4.18;

contract mortal {
    address public owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract mm is mortal {
  address public provider;
  address public user;
  bytes32 initialHash;
  bytes32 finalHash;

  mapping(uint64 => bool) public addressWasSubmitted; // marks an address as submitted
  mapping(uint64 => uint64) public valueSubmitted; // value submitted to address

  mapping(uint64 => bool) public addressWasWritten; // marks an address as written
  mapping(uint64 => uint64) public valueWritten; // value written to address

  enum state { WaitingValues, ReadAndWrite,
               UpdatingHash, Finished }
  state public currentState;

  event SubmittingValue(uint64 addressSubmitted, uint64 valueSubmitted);
  event WrittingValue(uint64 addressSubmitted, uint64 valueSubmitted);
  event UpdatingHash(uint64 addressSubmitted, uint64 valueSubmitted,
                     bytes32 newHash);
  event Finished();

  function mm(address theProvider; address theUser,
              bytes32 theInitialHash) public {
    require(theProvider != theUser);
    provider = theProvider;
    user = theUser;
    initialHash = theInitialHash;

    currentState = state.WaitingValues;
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
  /// @param postedTimes An array (of size querySize) with the times that have
  /// been queried.
  /// @param postedHashes An array (of size querySize) with the hashes
  /// corresponding to the queried times
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
  /// @param queryPiece is the index of queryArray corresponding to the left
  /// limit of the next interval to be queried.
  /// @param leftPoint confirmation of the leftPoint of the interval to be
  /// split. Should be an aggreement point.
  /// @param leftPoint confirmation of the rightPoint of the interval to be
  /// split. Should be a disagreement point.
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

