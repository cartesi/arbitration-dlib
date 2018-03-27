/// @title Partition contract
pragma solidity ^0.4.18;

library partitionLib {

  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon, DivergenceFound }

  struct partitionCtx {
    address challenger;
    address claimer;
    uint finalTime; // hashes provided between 0 and finalTime (inclusive)

    mapping(uint => bool) timeSubmitted; // marks a time as submitted
    mapping(uint => bytes32) timeHash; // hashes are signed by claimer

    uint querySize;
    uint[] queryArray;

    uint timeOfLastMove;
    uint roundDuration;

    state currentState;

    uint divergenceTime;
  }

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  event ChallengeEnded(uint8 theState);
  event DivergenceFound(uint timeOfDivergence, bytes32 hashAtDivergenceTime,
                        bytes32 hashRigthAfterDivergenceTime);

  function init(partitionCtx storage self, address theChallenger,
                address theClaimer, bytes32 theInitialHash,
                bytes32 theClaimerFinalHash, uint theFinalTime,
                uint theQuerySize, uint theRoundDuration) public
  {
    require(theChallenger != theClaimer);
    self.challenger = theChallenger;
    self.claimer = theClaimer;
    require(theFinalTime > 0);
    self.finalTime = theFinalTime;

    self.timeSubmitted[0] = true;
    self.timeSubmitted[self.finalTime] = true;
    self.timeHash[0] = theInitialHash;
    self.timeHash[self.finalTime] = theClaimerFinalHash;

    require(theQuerySize > 2);
    require(theQuerySize < 100);
    self.querySize = theQuerySize;
    for (uint i = 0; i < self.querySize; i++) {
      self.queryArray.push(0);
    }

    // slice the interval, placing the separators in queryArray
    slice(self, 0, self.finalTime);

    self.roundDuration = theRoundDuration;
    self.timeOfLastMove = now;

    self.currentState = state.WaitingHashes;
    emit QueryPosted(self.queryArray);
  }

  // split an interval using (querySize) points (placed in queryArray)
  // leftPoint rightPoint are always the first and last points in queryArray.
  function slice(partitionCtx storage self, uint leftPoint,
                 uint rightPoint) internal
  {
    require(rightPoint > leftPoint);
    uint i;
    uint intervalLength = rightPoint - leftPoint;
    // if intervalLength is not big enough to allow us jump sizes larger then
    // one, we go step by step
    if (intervalLength < 2 * (self.querySize - 1)) {
      for (i = 0; i < self.querySize - 1; i++) {
        if (leftPoint + i < rightPoint) {
          self.queryArray[i] = leftPoint + i;
        } else {
          self.queryArray[i] = rightPoint;
        }
      }
    } else {
      // otherwise: intervalLength = (querySize - 1) * divisionLength + j
      // with divisionLength >= 1 and j in {0, ..., querySize - 2}. in this
      // case the size of maximum slice drops to a proportion of intervalLength
      uint divisionLength = intervalLength / (self.querySize - 1);
      for (i = 0; i < self.querySize - 1; i++) {
        self.queryArray[i] = leftPoint + i * divisionLength;
      }
    }
    self.queryArray[self.querySize - 1] = rightPoint;
  }

  /// @notice Answer the query (only claimer can call it).
  /// @param postedTimes An array (of size querySize) with the times that have
  /// been queried.
  /// @param postedHashes An array (of size querySize) with the hashes
  /// corresponding to the queried times
  function replyQuery(partitionCtx storage self, uint[] postedTimes,
                      bytes32[] postedHashes) public
  {
    require(msg.sender == self.claimer);
    require(self.currentState == state.WaitingHashes);
    require(postedTimes.length == self.querySize);
    require(postedHashes.length == self.querySize);
    for (uint i = 0; i < self.querySize; i++) {
      // make sure the claimer knows the current query
      require(postedTimes[i] == self.queryArray[i]);
      // cannot rewrite previous answer
      if (!self.timeSubmitted[postedTimes[i]]) {
        self.timeSubmitted[postedTimes[i]] = true;
        self.timeHash[postedTimes[i]] = postedHashes[i];
      }
    }
    self.currentState = state.WaitingQuery;
    self.timeOfLastMove = now;
    emit HashesPosted(postedTimes, postedHashes);
  }

  /// @notice Makes a query (only challenger can call it).
  /// @param queryPiece is the index of queryArray corresponding to the left
  /// limit of the next interval to be queried.
  /// @param leftPoint confirmation of the leftPoint of the interval to be
  /// split. Should be an aggreement point.
  /// @param leftPoint confirmation of the rightPoint of the interval to be
  /// split. Should be a disagreement point.
  function makeQuery(partitionCtx storage self, uint queryPiece,
                     uint leftPoint, uint rightPoint) public
  {
    require(msg.sender == self.challenger);
    require(self.currentState == state.WaitingQuery);
    require(queryPiece < self.querySize - 1);
    // make sure the challenger knows the previous query
    require(leftPoint == self.queryArray[queryPiece]);
    require(rightPoint == self.queryArray[queryPiece + 1]);
    // no unitary queries. in unitary case, present divergence instead.
    // by avoiding unitary queries one forces the contest to end
    require(rightPoint - leftPoint > 1);
    slice(self, leftPoint, rightPoint);
    self.currentState = state.WaitingHashes;
    self.timeOfLastMove = now;
    emit QueryPosted(self.queryArray);
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime(partitionCtx storage self) public
  {
    if ((msg.sender == self.challenger)
        && (self.currentState == state.WaitingHashes)
        && (now > self.timeOfLastMove + self.roundDuration)) {
      self.currentState = state.ChallengerWon;
      emit ChallengeEnded(uint8(self.currentState));
    }
    if ((msg.sender == self.claimer)
        && (self.currentState == state.WaitingQuery)
        && (now > self.timeOfLastMove + self.roundDuration)) {
      self.currentState = state.ClaimerWon;
      emit ChallengeEnded(uint8(self.currentState));
    }
  }

  /// @notice Present a precise time of divergence (can only be called by
  /// challenger).
  /// @param theDivergenceTime The time when the divergence happended. It
  /// should be a point of aggreement, while theDivergenceTime + 1 should be a
  /// point of disagreement (both queried).
  function presentDivergence(partitionCtx storage self,
                             uint theDivergenceTime) public
  {
    require(msg.sender == self.challenger);
    require(theDivergenceTime < self.finalTime);
    require(self.timeSubmitted[theDivergenceTime]);
    require(self.timeSubmitted[theDivergenceTime + 1]);
    self.divergenceTime = theDivergenceTime;
    self.currentState = state.DivergenceFound;
    emit ChallengeEnded(uint8(self.currentState));
    emit DivergenceFound(self.divergenceTime,
                         self.timeHash[self.divergenceTime],
                         self.timeHash[self.divergenceTime + 1]);
  }
}

