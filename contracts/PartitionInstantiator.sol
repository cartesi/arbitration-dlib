/// @title Partition instantiator
pragma solidity ^0.4.18;

contract PartitionInstantiator {
  uint32 private currentIndex = 0;

  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon, DivergenceFound }

  struct PartitionCtx {
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

  mapping(uint32 => PartitionCtx) private instance;

  event PartitionCreated(uint32 _index);
  event QueryPosted(uint32 _index, uint[] _queryTimes);
  event HashesPosted(uint32 _index, uint[] _postedTimes, bytes32[] _postedHashes);
  event ChallengeEnded(uint32 _index, uint8 _state);
  event DivergenceFound(uint32 _index, uint _timeOfDivergence,
                        bytes32 _hashAtDivergenceTime,
                        bytes32 _hashRigthAfterDivergenceTime);

  function instantiate(address _challenger,
                       address _claimer, bytes32 _initialHash,
                       bytes32 _claimerFinalHash, uint _finalTime,
                       uint _querySize, uint _roundDuration) public
  {
    require(_challenger != _claimer);
    require(_finalTime > 0);
    require(_querySize > 2);
    require(_querySize < 100);
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].finalTime = _finalTime;
    instance[currentIndex].timeSubmitted[0] = true;
    instance[currentIndex].timeSubmitted[_finalTime] = true;
    instance[currentIndex].timeHash[0] = _initialHash;
    instance[currentIndex].timeHash[_finalTime] = _claimerFinalHash;
    instance[currentIndex].querySize = _querySize;
    // initialize queryArray with zeros
    for (uint i = 0; i < instance[currentIndex].querySize; i++) {
      instance[currentIndex].queryArray.push(0);
    }
    // slice the interval, placing the separators in queryArray
    slice(currentIndex, 0, instance[currentIndex].finalTime);
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitingHashes;
    emit PartitionCreated(currentIndex);
    emit QueryPosted(currentIndex, instance[currentIndex].queryArray);
    currentIndex++;
  }

  // split an interval using (querySize) points (placed in queryArray)
  // leftPoint rightPoint are always the first and last points in queryArray.
  function slice(uint32 _index, uint leftPoint, uint rightPoint) internal
  {
    require(rightPoint > leftPoint);
    uint i;
    uint intervalLength = rightPoint - leftPoint;
    // if intervalLength is not big enough to allow us jump sizes larger then
    // one, we go step by step
    if (intervalLength < 2 * (instance[_index].querySize - 1)) {
      for (i = 0; i < instance[_index].querySize - 1; i++) {
        if (leftPoint + i < rightPoint) {
          instance[_index].queryArray[i] = leftPoint + i;
        } else {
          instance[_index].queryArray[i] = rightPoint;
        }
      }
    } else {
      // otherwise: intervalLength = (querySize - 1) * divisionLength + j
      // with divisionLength >= 1 and j in {0, ..., querySize - 2}. in this
      // case the size of maximum slice drops to a proportion of intervalLength
      uint divisionLength = intervalLength / (instance[_index].querySize - 1);
      for (i = 0; i < instance[_index].querySize - 1; i++) {
        instance[_index].queryArray[i] = leftPoint + i * divisionLength;
      }
    }
    instance[_index].queryArray[instance[_index].querySize - 1] = rightPoint;
  }

  /// @notice Answer the query (only claimer can call it).
  /// @param postedTimes An array (of size querySize) with the times that have
  /// been queried.
  /// @param postedHashes An array (of size querySize) with the hashes
  /// corresponding to the queried times
  function replyQuery(uint32 _index, uint[] postedTimes,
                      bytes32[] postedHashes) public
  {
    require(msg.sender == instance[_index].claimer);
    require(instance[_index].currentState == state.WaitingHashes);
    require(postedTimes.length == instance[_index].querySize);
    require(postedHashes.length == instance[_index].querySize);
    for (uint i = 0; i < instance[_index].querySize; i++) {
      // make sure the claimer knows the current query
      require(postedTimes[i] == instance[_index].queryArray[i]);
      // cannot rewrite previous answer
      if (!instance[_index].timeSubmitted[postedTimes[i]]) {
        instance[_index].timeSubmitted[postedTimes[i]] = true;
        instance[_index].timeHash[postedTimes[i]] = postedHashes[i];
      }
    }
    instance[_index].currentState = state.WaitingQuery;
    instance[_index].timeOfLastMove = now;
    emit HashesPosted(_index, postedTimes, postedHashes);
  }

  /// @notice Makes a query (only challenger can call it).
  /// @param queryPiece is the index of queryArray corresponding to the left
  /// limit of the next interval to be queried.
  /// @param leftPoint confirmation of the leftPoint of the interval to be
  /// split. Should be an aggreement point.
  /// @param leftPoint confirmation of the rightPoint of the interval to be
  /// split. Should be a disagreement point.
  function makeQuery(uint32 _index, uint queryPiece,
                     uint leftPoint, uint rightPoint) public
  {
    require(msg.sender == instance[_index].challenger);
    require(instance[_index].currentState == state.WaitingQuery);
    require(queryPiece < instance[_index].querySize - 1);
    // make sure the challenger knows the previous query
    require(leftPoint == instance[_index].queryArray[queryPiece]);
    require(rightPoint == instance[_index].queryArray[queryPiece + 1]);
    // no unitary queries. in unitary case, present divergence instead.
    // by avoiding unitary queries one forces the contest to end
    require(rightPoint - leftPoint > 1);
    slice(_index, leftPoint, rightPoint);
    instance[_index].currentState = state.WaitingHashes;
    instance[_index].timeOfLastMove = now;
    emit QueryPosted(_index, instance[_index].queryArray);
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime(uint32 _index) public
  {
    if ((msg.sender == instance[_index].challenger)
        && (instance[_index].currentState == state.WaitingHashes)
        && (now > instance[_index].timeOfLastMove + instance[_index].roundDuration)) {
      instance[_index].currentState = state.ChallengerWon;
      emit ChallengeEnded(_index, uint8(instance[_index].currentState));
      return;
    }
    if ((msg.sender == instance[_index].claimer)
        && (instance[_index].currentState == state.WaitingQuery)
        && (now > instance[_index].timeOfLastMove + instance[_index].roundDuration)) {
      instance[_index].currentState = state.ClaimerWon;
      emit ChallengeEnded(_index, uint8(instance[_index].currentState));
      return;
    }
    require(false);
  }

  /// @notice Present a precise time of divergence (can only be called by
  /// challenger).
  /// @param _divergenceTime The time when the divergence happended. It
  /// should be a point of aggreement, while _divergenceTime + 1 should be a
  /// point of disagreement (both queried).
  function presentDivergence(uint32 _index, uint _divergenceTime) public
  {
    require(msg.sender == instance[_index].challenger);
    require(_divergenceTime < instance[_index].finalTime);
    require(instance[_index].timeSubmitted[_divergenceTime]);
    require(instance[_index].timeSubmitted[_divergenceTime + 1]);
    instance[_index].divergenceTime = _divergenceTime;
    instance[_index].currentState = state.DivergenceFound;
    emit ChallengeEnded(_index, uint8(instance[_index].currentState));
    emit DivergenceFound(_index, instance[_index].divergenceTime,
                         instance[_index].timeHash[instance[_index].divergenceTime],
                         instance[_index].timeHash[instance[_index].divergenceTime + 1]);
  }
  // Getters methods

  function challenger(uint32 _index) public view returns (address) {
    return instance[_index].challenger;
  }

  function claimer(uint32 _index) public view returns (address) {
    return instance[_index].claimer;
  }

  function finalTime(uint32 _index) public view returns (uint) {
    return instance[_index].finalTime;
  }

  function timeSubmitted(uint32 _index, uint key) public view returns (bool) {
    return instance[_index].timeSubmitted[key];
  }

  function timeHash(uint32 _index, uint key) public view returns (bytes32) {
    return instance[_index].timeHash[key];
  }

  function querySize(uint32 _index) public view returns (uint) {
    return instance[_index].querySize;
  }

  function queryArray(uint32 _index, uint i) public view returns (uint) {
    return instance[_index].queryArray[i];
  }

  function timeOfLastMove(uint32 _index) public view returns (uint) {
    return instance[_index].timeOfLastMove;
  }

  function roundDuration(uint32 _index) public view returns (uint) {
    return instance[_index].roundDuration;
  }

  function currentState(uint32 _index) public view
    returns (PartitionInstantiator.state)
  {
    return instance[_index].currentState;
  }

  function divergenceTime(uint32 _index) public view returns (uint) {
    return instance[_index].divergenceTime;
  }
}

