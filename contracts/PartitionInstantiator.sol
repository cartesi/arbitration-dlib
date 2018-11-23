/// @title Partition instantiator
pragma solidity 0.4.24;

import "./Decorated.sol";
import "./PartitionInterface.sol";

contract PartitionInstantiator is PartitionInterface, Decorated {

  // IMPLEMENT GARBAGE COLLECTOR AFTER AN INSTACE IS FINISHED!
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
  
  //Swap internal/private when done with testing
  mapping(uint256 => PartitionCtx) internal instance;

  // These are the possible states and transitions of the contract.
  //
  //          +---+
  //          |   |
  //          +---+
  //            |
  //            | instantiate
  //            v
  //          +---------------+  claimVictoryByTimeout  +---------------+
  //          | WaitingHashes |------------------------>| ChallengerWon |
  //          +---------------+                         +---------------+
  //            |  ^
  // replyQuery |  | makeQuery
  //            v  |
  //          +--------------+   claimVictoryByTimeout  +------------+
  //          | WaitingQuery |------------------------->| ClaimerWon |
  //          +--------------+                          +------------+
  //            |
  //            | presentDivergence
  //            v
  //          +-----------------+
  //          | DivergenceFound |
  //          +-----------------+
  //

  event PartitionCreated(uint256 _index);
  event QueryPosted(uint256 _index);
  event HashesPosted(uint256 _index);
  event ChallengeEnded(uint256 _index, uint8 _state);
  event DivergenceFound(uint256 _index, uint _timeOfDivergence,
                        bytes32 _hashAtDivergenceTime,
                        bytes32 _hashRigthAfterDivergenceTime);

  function instantiate(address _challenger,
                       address _claimer, bytes32 _initialHash,
                       bytes32 _claimerFinalHash, uint _finalTime,
                       uint _querySize, uint _roundDuration) public
    returns(uint256)
  {
    require(_challenger != _claimer, "Challenger and claimer have the same address");
    require(_finalTime > 0, "Final Time has to be bigger than zero");
    require(_querySize > 2, "_querySize has to be bigger than two");
    require(_querySize < 20, "_querySize has to be less than 20");
    require(_roundDuration > 50, "Round Duration has to be greater than 50 seconds");
    instance[currentIndex].challenger = _challenger;
    instance[currentIndex].claimer = _claimer;
    instance[currentIndex].finalTime = _finalTime;
    instance[currentIndex].timeSubmitted[0] = true;
    instance[currentIndex].timeSubmitted[_finalTime] = true;
    instance[currentIndex].timeHash[0] = _initialHash;
    instance[currentIndex].timeHash[_finalTime] = _claimerFinalHash;
    instance[currentIndex].querySize = _querySize;
    // Creates queryArray with the correct size
    instance[currentIndex].queryArray = new uint[] (instance[currentIndex].querySize);
    // slice the interval, placing the separators in queryArray
    slice(currentIndex, 0, instance[currentIndex].finalTime);
    instance[currentIndex].roundDuration = _roundDuration;
    instance[currentIndex].timeOfLastMove = now;
    instance[currentIndex].currentState = state.WaitingHashes;
    emit PartitionCreated(currentIndex);
    emit QueryPosted(currentIndex);
    
    return currentIndex++;
  }

  // split an interval using (querySize) points (placed in queryArray)
  // leftPoint rightPoint are always the first and last points in queryArray.
  function slice(uint256 _index, uint leftPoint, uint rightPoint) internal
  {
    require(rightPoint > leftPoint, "rightPoint has to be bigger than leftPoint");
    uint i;
    uint intervalLength = rightPoint - leftPoint;
    uint queryLastIndex = instance[_index].querySize - 1;
    // if intervalLength is not big enough to allow us jump sizes larger then
    // one, we go step by step
    if (intervalLength < 2 * queryLastIndex) {
      for (i = 0; i < queryLastIndex; i++) {
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
      uint divisionLength = intervalLength / queryLastIndex;
      for (i = 0; i < queryLastIndex; i++) {
        instance[_index].queryArray[i] = leftPoint + i * divisionLength;
      }
    }
    instance[_index].queryArray[queryLastIndex] = rightPoint;
  }

  /// @notice Answer the query (only claimer can call it).
  /// @param postedTimes An array (of size querySize) with the times that have
  /// been queried.
  /// @param postedHashes An array (of size querySize) with the hashes
  /// corresponding to the queried times
  function replyQuery(uint256 _index, uint[] postedTimes,
                      bytes32[] postedHashes) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].claimer)
  {
    require(instance[_index].currentState == state.WaitingHashes, "State is not WaitingHashes");
    require(postedTimes.length == instance[_index].querySize, "postedTimes.length != querySize");
    require(postedHashes.length == instance[_index].querySize, "postedHashes.length != querySize");
    for (uint i = 0; i < instance[_index].querySize; i++) {
      // make sure the claimer knows the current query
      require(postedTimes[i] == instance[_index].queryArray[i], "postedTimes[i] != queryArray[i]");
      // cannot rewrite previous answer
      if (!instance[_index].timeSubmitted[postedTimes[i]]) {
        instance[_index].timeSubmitted[postedTimes[i]] = true;
        instance[_index].timeHash[postedTimes[i]] = postedHashes[i];
      }
    }
    instance[_index].currentState = state.WaitingQuery;
    instance[_index].timeOfLastMove = now;
    emit HashesPosted(_index);
  }

  /// @notice Makes a query (only challenger can call it).
  /// @param queryPiece is the index of queryArray corresponding to the left
  /// limit of the next interval to be queried.
  /// @param leftPoint confirmation of the leftPoint of the interval to be
  /// split. Should be an aggreement point.
  /// @param leftPoint confirmation of the rightPoint of the interval to be
  /// split. Should be a disagreement point.
  function makeQuery(uint256 _index, uint queryPiece,
                     uint leftPoint, uint rightPoint) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
  {
    require(instance[_index].currentState == state.WaitingQuery, "State is not WaitingQuery");
    require(queryPiece < instance[_index].querySize - 1, "queryPiece is bigger thatn querySize -1");
    // make sure the challenger knows the previous query
    require(leftPoint == instance[_index].queryArray[queryPiece], "leftPoint != queryArray[queryPiece]");
    require(rightPoint == instance[_index].queryArray[queryPiece + 1],"rightPoint != queryArray[queryPiece]");
    // no unitary queries. in unitary case, present divergence instead.
    // by avoiding unitary queries one forces the contest to end
    require(rightPoint - leftPoint > 1,"Interval is less than one");
    slice(_index, leftPoint, rightPoint);
    instance[_index].currentState = state.WaitingHashes;
    instance[_index].timeOfLastMove = now;
    emit QueryPosted(_index);
  }

  /// @notice Claim victory for opponent timeout.
  function claimVictoryByTime(uint256 _index) public
    onlyInstantiated(_index)
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
    revert();
  }

  /// @notice Present a precise time of divergence (can only be called by
  /// challenger).
  /// @param _divergenceTime The time when the divergence happended. It
  /// should be a point of aggreement, while _divergenceTime + 1 should be a
  /// point of disagreement (both queried).
  function presentDivergence(uint256 _index, uint _divergenceTime) public
    onlyInstantiated(_index)
    onlyBy(instance[_index].challenger)
  {
    require(_divergenceTime < instance[_index].finalTime, "divergence time has to be less than finalTime");
    require(instance[_index].timeSubmitted[_divergenceTime],"_divergenceTime has to have been submitted");
    require(instance[_index].timeSubmitted[_divergenceTime + 1], "_divergenceTime +1 has to have been submitted");

    instance[_index].divergenceTime = _divergenceTime;
    instance[_index].currentState = state.DivergenceFound;
    emit ChallengeEnded(_index, uint8(instance[_index].currentState));
    emit DivergenceFound(_index, instance[_index].divergenceTime,
                         instance[_index].timeHash[instance[_index].divergenceTime],
                         instance[_index].timeHash[instance[_index].divergenceTime + 1]);
  }

  // Getters methods

  /*
  function getInstance(uint256 _index) public view
    onlyInstantiated(_index)
    returns (address challenger,
             address claimer,
             uint finalTime,
             uint querySize,
             uint timeOfLastMove,
             uint roundDuration,
             uint divergenceTime)
  {
    return (instance[_index].challenger,
            instance[_index].claimer,
            instance[_index].finalTime,
            instance[_index].querySize,
            instance[_index].timeOfLastMove,
            instance[_index].roundDuration,
            instance[_index].divergenceTime);
  }
  */

  /*
  function challenger(uint256 _index) public view returns (address) {
    return instance[_index].challenger;
  }

  function claimer(uint256 _index) public view returns (address) {
    return instance[_index].claimer;
  }

  function finalTime(uint256 _index) public view returns (uint) {
    return instance[_index].finalTime;
  }

  function querySize(uint256 _index) public view returns (uint) {
    return instance[_index].querySize;
  }

  function timeOfLastMove(uint256 _index) public view returns (uint) {
    return instance[_index].timeOfLastMove;
  }

  function roundDuration(uint256 _index) public view returns (uint) {
    return instance[_index].roundDuration;
  }
  */
  function divergenceTime(uint256 _index) public view
    onlyInstantiated(_index)
    returns (uint)
  { return instance[_index].divergenceTime; }

  function timeSubmitted(uint256 _index, uint key) public view
    onlyInstantiated(_index)
    returns (bool)
  { return instance[_index].timeSubmitted[key]; }

  function timeHash(uint256 _index, uint key) public view
    onlyInstantiated(_index)
    returns (bytes32)
  { return instance[_index].timeHash[key]; }

  function queryArray(uint256 _index, uint i) public view
    onlyInstantiated(_index)
    returns (uint)
  { return instance[_index].queryArray[i]; }

  // state getters

  function stateIsWaitingQuery(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitingQuery; }

  function stateIsWaitingHashes(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.WaitingHashes; }

  function stateIsChallengerWon(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.ChallengerWon; }

  function stateIsClaimerWon(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.ClaimerWon; }

  function stateIsDivergenceFound(uint256 _index) public view
    onlyInstantiated(_index)
    returns(bool)
  { return instance[_index].currentState == state.DivergenceFound; }
}
