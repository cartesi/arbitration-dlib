// @title Verification game instantiator
pragma solidity ^0.4.23;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";
import "./lib/bokkypoobah/Token.sol";

contract VGInterface is Instantiator
{
  enum state { WaitSale, WaitPartition, WaitMemoryProveValues,
               FinishedClaimerWon, FinishedChallengerWon }

  function instantiate(address _challenger, address _claimer, uint _valueXYZ,
                       uint _roundDuration, uint _salesDuration,
                       address _machineAddress, bytes32 _initialHash,
                       bytes32 _claimerFinalHash, uint _finalTime)
    public returns (uint256);
  function setChallengerPrice(uint256 _index, uint _newPrice,
                              uint _doubleDown) public;
  function setClaimerPrice(uint256 _index, uint _newPrice,
                           uint _doubleDown) public;
  function buyInstanceFromChallenger(uint256 _index) public;
  function buyInstanceFromClaimer(uint256 _index) public;
  function finishSalePhase(uint256 _index) public;
  function winByPartitionTimeout(uint256 _index) public;
  function startMachineRunChallenge(uint256 _index) public;
  function settleVerificationGame(uint256 _index) public;
  function claimVictoryByDeadline(uint256 _index) public;
  function challengerWins(uint256 _index) private;
  function claimerWins(uint256 _index) private;
  function clearInstance(uint256 _index) internal;
  function stateIsWaitSale(uint256 _index) public view returns(bool);
  function stateIsWaitPartition(uint256 _index) public view returns(bool);
  function stateIsWaitMemoryProveValues(uint256 _index) public view
    returns(bool);
  function stateIsFinishedClaimerWon(uint256 _index) public view returns(bool);
  function stateIsFinishedChallengerWon(uint256 _index) public view
    returns(bool);
}
