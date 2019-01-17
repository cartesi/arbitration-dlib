// @title Verification game instantiator
pragma solidity ^0.4.25;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";

contract VGInterface is Instantiator
{
  enum state { WaitPartition, WaitMemoryProveValues,
               FinishedClaimerWon, FinishedChallengerWon }
  function getCurrentState(uint256 _index) public view
    returns (bytes32);

  function instantiate(address _challenger, address _claimer,
                       uint _roundDuration, address _machineAddress,
                       bytes32 _initialHash, bytes32 _claimerFinalHash,
                       uint _finalTime)
    public returns (uint256);
  function winByPartitionTimeout(uint256 _index) public;
  function startMachineRunChallenge(uint256 _index) public;
  function settleVerificationGame(uint256 _index) public;
  function claimVictoryByDeadline(uint256 _index) public;
  function challengerWins(uint256 _index) private;
  function claimerWins(uint256 _index) private;
  function clearInstance(uint256 _index) internal;
  function stateIsWaitPartition(uint256 _index) public view returns(bool);
  function stateIsWaitMemoryProveValues(uint256 _index) public view
    returns(bool);
  function stateIsFinishedClaimerWon(uint256 _index) public view returns(bool);
  function stateIsFinishedChallengerWon(uint256 _index) public view
    returns(bool);
}
