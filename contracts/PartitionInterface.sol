/// @title Memory manager contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./PartitionLib.sol";

contract PartitionInterface is mortal
{
  using PartitionLib for PartitionLib.PartitionCtx;
  PartitionLib.PartitionCtx partition;

  event QueryPosted(uint[] _queryTimes);
  event HashesPosted(uint[] _postedTimes, bytes32[] _postedHashes);
  event ChallengeEnded(uint8 _state);
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

  function PartitionInterface(address _challenger, address _claimer,
                              bytes32 _initialHash,
                              bytes32 _claimerFinalHash, uint _finalTime,
                              uint _querySize, uint _roundDuration) public
  {
    require(owner != _challenger);
    require(owner != _claimer);
    partition.init(_challenger, _claimer, _initialHash,
                   _claimerFinalHash, _finalTime, _querySize,
                   _roundDuration);
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

  function presentDivergence(uint _divergenceTime) public
  {
    partition.presentDivergence(_divergenceTime);
  }
}

