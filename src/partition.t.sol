/// @title Partition contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./partition.sol";

contract partitionTest is mortal {

  using partitionLib for partitionLib.partitionCtx;
  partitionLib.partitionCtx partition;

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  //event ChallengeEnded();//partitionLib.state theState);
  event ChallengeEnded(uint8 theState);
  event DivergenceFound(uint timeOfDivergence, bytes32 hashAtDivergenceTime,
                        bytes32 hashRigthAfterDivergenceTime);

  function partitionTest(address theChallenger, address theClaimer,
                         bytes32 theInitialHash, bytes32 theClaimerFinalHash,
                         uint theFinalTime, uint theQuerySize,
                         uint theRoundDuration) public
  {
    partition.init(theChallenger, theClaimer, theInitialHash,
                   theClaimerFinalHash, theFinalTime, theQuerySize,
                   theRoundDuration);
  }

  function slice(uint leftPoint, uint rightPoint) internal
  {
    partition.slice(leftPoint, rightPoint);
  }

  function replyQuery(uint[] postedTimes, bytes32[] postedHashes) public
  {
    partition.replyQuery(postedTimes, postedHashes);
  }

  function makeQuery(uint queryPiece, uint leftPoint, uint rightPoint) public
  {
    partition.makeQuery(queryPiece, leftPoint, rightPoint);
  }

  function claimVictoryByTime() public
  {
    partition.claimVictoryByTime();
  }

  function presentDivergence(uint theDivergenceTime) public
  {
    partition.presentDivergence(theDivergenceTime);
  }

  // external interaction
  function currentState() public view returns (partitionLib.state) {
    return partition.currentState;
  }

  function queryArray(uint i) public view returns (uint) {
    return partition.queryArray[i];
  }
}

