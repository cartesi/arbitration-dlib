pragma solidity ^0.4.0;

contract mortal {
    address public owner;

    function mortal() public { owner = msg.sender; }
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract partition is mortal {
  address public challenger;
  address public claimer;
  uint public finalTime;

  mapping(uint => bool) public timeSubmitted;
  mapping(uint => bytes32) public timeHash;

  uint public querySize;
  uint[] queryArray;

  uint public maxQueryNumber;
  uint private _currentQueryNumber;

  uint public timeOfLastReply;
  uint public roundDuration;

  enum state { WaitingQueries, WaitingHashes, ChallengerWon,
               ClaimerWon, DivergenceFound }
  state currentState;

  uint divergenceTime;

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  event ChallengeEnded(state theState);

  function partition(address theChallenger, address theClaimer,
                     uint theFinalTime, uint theQuerySize,
                     bytes32 theInitialHash, bytes32 theFinalHash,
                     uint theMaxQueryNumber, uint theRoundDuration) public {
    challenger = theChallenger;
    claimer = theClaimer;
    require(theFinalTime != 0);
    finalTime = theFinalTime;

    timeSubmitted[0] = true;
    timeSubmitted[finalTime] = true;
    timeHash[0] = theInitialHash;
    timeHash[finalTime] = theFinalHash;

    querySize = theQuerySize;
    for (uint i = 0; i < querySize; i++) {
      queryArray.push(0);
    }

    maxQueryNumber = theMaxQueryNumber;
    _currentQueryNumber = 0;

    timeOfLastReply = now;
    roundDuration = theRoundDuration;

    currentState = state.WaitingQueries;
  }

  function makeQuery(uint[] queryTimes) public {
    require(currentState == state.WaitingQueries);
    require(msg.sender == challenger);
    require(queryTimes.length == querySize);
    require(_currentQueryNumber < maxQueryNumber);
    for (uint i = 0; i < querySize; i++) {
      require(queryTimes[i] <= finalTime);
      queryArray[i] = queryTimes[i];
    }
    _currentQueryNumber++;
    currentState = state.WaitingHashes;
    timeOfLastReply = now;
    QueryPosted(queryTimes);
  }

  function replyQuery(uint[] postedTimes, bytes32[] postedHashes) public {
    require(currentState == state.WaitingHashes);
    require(msg.sender == claimer);
    require(postedTimes.length == querySize);
    require(postedHashes.length == querySize);
    for (uint i = 0; i < querySize; i++) {
      require(postedTimes[i] == queryArray[i]);
      timeSubmitted[postedTimes[i]] = true;
      timeHash[postedTimes[i]] = postedHashes[i];
    }
    currentState = state.WaitingQueries;
    timeOfLastReply = now;
    HashesPosted(postedTimes, postedHashes);
  }

  function claimVictory() public {
    if (msg.sender == challenger && currentState == state.WaitingHashes
        && now > timeOfLastReply + roundDuration)
      { currentState = state.ChallengerWon;
        ChallengeEnded(currentState);
      }
    if (msg.sender == claimer && currentState == state.WaitingQueries
        && now > timeOfLastReply + roundDuration)
      { currentState = state.ClaimerWon;
        ChallengeEnded(currentState);
      }
    revert();
  }

  function presentDivergence(uint theDivergenceTime) public {
    require(msg.sender == challenger);
    divergenceTime = theDivergenceTime;
    currentState = state.DivergenceFound;
    ChallengeEnded(currentState);
  }
}

