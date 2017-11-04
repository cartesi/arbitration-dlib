pragma solidity ^0.4.0;

contract mortal {
    address public owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract partition is mortal {
  address public challenger;
  address public claimer;
  uint public finalTime; // the hashes are between 0 and finalTime (inclusive)

  mapping(uint => bool) public timeSubmitted; // marks a time as queried
  mapping(uint => bytes32) public timeHash; // hashes signed by claimer

  uint public querySize;
  uint[] public queryArray;

  uint public maxNumberOfQueries;
  uint public numberOfQueriesMade;

  uint public timeOfLastMove;
  uint public roundDuration;

  enum state { WaitingQuery, WaitingHashes, ChallengerWon,
               ClaimerWon, DivergenceFound }
  state public currentState;

  uint private divergenceTime;

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  event ChallengeEnded(state theState);
  event DivergenceFound(uint timeOfDivergence, bytes32 hashAtDivergenceTime,
                        bytes32 hashRigthAfterDivergenceTime);

  //event BoolDebug(bool bla);

  // initialHash and finalHash have been given by claimer
  //function partition(address theChallenger, address theClaimer,
  //                   uint theFinalTime) public {
  //  require(theChallenger != theClaimer);
  //  challenger = theChallenger;
  //  claimer = theClaimer;
  //  require(theFinalTime > 0);
  //  finalTime = theFinalTime;
  //
  //}
  //function partition() public {  };
  function partition(address theChallenger, address theClaimer,
                     bytes32 theInitialHash, bytes32 theFinalHash,
                     uint theFinalTime, uint theQuerySize,
                     uint theMaxNumberOfQueries, uint theRoundDuration) public {
    require(theChallenger != theClaimer);
    challenger = theChallenger;
    claimer = theClaimer;
    require(theFinalTime > 0);
    finalTime = theFinalTime;

    timeSubmitted[0] = true;
    timeSubmitted[finalTime] = true;
    timeHash[0] = theInitialHash;
    timeHash[finalTime] = theFinalHash;

    require(theQuerySize > 2);
    querySize = theQuerySize;
    for (uint i = 0; i < querySize; i++) { queryArray.push(0); }
    // slice the interval, placing the separators in queryArray
    slice(0, finalTime);

    maxNumberOfQueries = theMaxNumberOfQueries;
    numberOfQueriesMade = 0;

    timeOfLastMove = now;
    roundDuration = theRoundDuration;

    currentState = state.WaitingHashes;
  }

  // split an interval using (querySize) points queryArray
  // leftPoint rightPoint are always the first and last points in queryArray.
  function slice(uint leftPoint, uint rightPoint) internal {
    require(rightPoint > leftPoint);
    uint intervalLength = rightPoint - leftPoint;
    uint i;
    // if intervalLength is not big enough to allow us jump sizes larger then
    // one, we go step by step. we will finish in one or two further slices
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
      // case the maximum slice size drops to a proportion of intervalLength
      uint divisionLength = intervalLength / (querySize - 1);
      for (i = 0; i < querySize - 1; i++) {
        queryArray[i] = leftPoint + i * divisionLength;
      }
    }
    queryArray[querySize - 1] = rightPoint;
  }

  function makeQuery(uint queryPiece, uint leftPoint, uint rightPoint) public {
    require(msg.sender == challenger);
    require(currentState == state.WaitingQuery);
    require(numberOfQueriesMade < maxNumberOfQueries);
    require(queryPiece < querySize - 1);
    // make sure the challenger knows the previous query
    require(leftPoint == queryArray[queryPiece]);
    require(rightPoint == queryArray[queryPiece + 1]);
    // no unitary queries. in that case, present divergence instead
    require(rightPoint - leftPoint > 1);
    slice(leftPoint, rightPoint);
    numberOfQueriesMade++;
    currentState = state.WaitingHashes;
    timeOfLastMove = now;
    QueryPosted(queryArray);
  }

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
    timeOfLastMove = now;
    HashesPosted(postedTimes, postedHashes);
  }

  function claimVictoryByTime() public {
    if (msg.sender == challenger && currentState == state.WaitingHashes
        && now > timeOfLastMove + roundDuration)
      { currentState = state.ChallengerWon;
        ChallengeEnded(currentState);
      }
    if (msg.sender == claimer && currentState == state.WaitingQuery
        && now > timeOfLastMove + roundDuration)
      { currentState = state.ClaimerWon;
        ChallengeEnded(currentState);
      }
  }

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

