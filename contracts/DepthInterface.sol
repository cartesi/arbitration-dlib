/// @title Depth interfacing contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./DepthLib.sol";

contract DepthInterface is mortal {

  using DepthLib for DepthLib.DepthCtx;
  DepthLib.DepthCtx depth;

  event QueryPosted(uint8 theCurrentDepth, uint64 theCurrentAddress);
  event HashesPosted(bytes32 theLeftHash, bytes32 theRightHash);
  event ChallengeEnded(uint8 theState);
  event ControversialPhrasePosted(uint64 addressStartingDivergence,
                                  bytes32 theControversialPhraseOfClaimer);

  // Getters methods

  function challenger() public view returns (address) {
    return depth.challenger;
  }

  function claimer() public view returns (address) {
    return depth.claimer;
  }

  function timeOfLastMove() public view returns (uint) {
    return depth.timeOfLastMove;
  }

  function roundDuration() public view returns (uint) {
    return depth.roundDuration;
  }

  function claimerCurrentHash() public view returns (bytes32) {
    return depth.claimerCurrentHash;
  }

  function claimerLeftChildHash() public view returns (bytes32) {
    return depth.claimerLeftChildHash;
  }

  function claimerRightChildHash() public view returns (bytes32) {
    return depth.claimerRightChildHash;
  }

  function currentDepth() public view returns (uint8) {
    return depth.currentDepth;
  }

  function currentAddress() public view returns (uint64) {
    return depth.currentAddress;
  }

  function controvesialPhraseOfClaimer() public view returns (bytes32) {
    return depth.controversialPhraseOfClaimer;
  }

  function currentState() public view returns (DepthLib.state) {
    return depth.currentState;
  }

  // Library functions

  function DepthInterface(address _challenger,
                          address _claimer, bytes32 _claimerHashOfRoot,
                          uint _roundDuration) public
  {
    require(owner != _challenger);
    require(owner != _claimer);
    depth.init(_challenger, _claimer, _claimerHashOfRoot,
               _roundDuration);
  }

  function replyQuery(bytes32 leftHash, bytes32 rightHash) public
  {
    depth.replyQuery(leftHash, rightHash);
  }

  function makeQuery(bool continueToTheLeft, bytes32 differentHash) public
  {
    depth.makeQuery(continueToTheLeft, differentHash);
  }

  function postControversialPhrase(bytes8 word1, bytes8 word2,
                                   bytes8 word3, bytes8 word4)
    public
  {
    return depth.postControversialPhrase(word1, word2, word3, word4);
  }

  function claimVictoryByTime()
    public
  {
    depth.claimVictoryByTime();
  }
}
