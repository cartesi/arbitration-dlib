/// @title Memory manager contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./PartitionLib.sol";

contract PartitionInterface is mortal {

  using PartitionLib for PartitionLib.PartitionCtx;
  PartitionLib.PartitionCtx partition;

  event QueryPosted(uint[] theQueryTimes);
  event HashesPosted(uint[] thePostedTimes, bytes32[] thePostedHashes);
  event ChallengeEnded(uint8 theState);
  event DivergenceFound(uint timeOfDivergence, bytes32 hashAtDivergenceTime,
                        bytes32 hashRigthAfterDivergenceTime);

  // Getters methods

  function challenger() public view returns (address) {
    return partition.challenger;
  }

  function claimer() public view returns (address) {
    return partition.claimer;
  }

  function finalTime() public view returns (uint) {
    return partition.finalTime;
  }

  function timeSubmitted(uint key) public view returns (bool) {
    return partition.timeSubmitted[key];
  }

  function timeHash(uint key) public view returns (bytes32) {
    return partition.timeHash[key];
  }

  function querySize() public view returns (uint) {
    return partition.querySize;
  }

  function queryArray(uint i) public view returns (uint) {
    return partition.queryArray[i];
  }

  function timeOfLastMove() public view returns (uint) {
    return partition.timeOfLastMove;
  }

  function roundDuration() public view returns (uint) {
    return partition.roundDuration;
  }

  function currentState() public view returns (PartitionLib.state) {
    return partition.currentState;
  }

  function divergenceTime() public view returns (uint) {
    return partition.divergenceTime;
  }

  // Library functions

  function PartitionInterface(address theChallenger, address theClaimer,
                              bytes32 theInitialHash,
                              bytes32 theClaimerFinalHash, uint theFinalTime,
                              uint theQuerySize, uint theRoundDuration) public
  {
    require(owner != theChallenger);
    require(owner != theClaimer);
    partition.init(theChallenger, theClaimer, theInitialHash,
                   theClaimerFinalHash, theFinalTime, theQuerySize,
                   theRoundDuration);
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
}

