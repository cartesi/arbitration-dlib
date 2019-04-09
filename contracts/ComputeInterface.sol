/// @title Interface for memory manager instantiator
pragma solidity 0.5;

import "./Instantiator.sol";

contract ComputeInterface is Instantiator
{
  enum state { WaitingClaim, WaitingConfirmation, ClaimerMissedDeadline,
               WaitingChallenge, ChallengerWon, ClaimerWon, ConsensusResult }
  function getCurrentState(uint256 _index) public view
    returns (bytes32);

  function instantiate(address _challenger, address _claimer,
                       uint256 _roundDuration, address _machineAddress,
                       bytes32 _initialHash, uint256 _finalTime) public
    returns (uint256);
  function submitClaim(uint256 _index, bytes32 _claimedFinalHash) public;
  function confirm(uint256 _index) public;
  function challenge(uint256 _index) public;
  function winByVG(uint256 _index) public;
  function claimVictoryByTime(uint256 _index) public;
  function isConcerned(uint256 _index, address _user) public view returns(bool);
}
