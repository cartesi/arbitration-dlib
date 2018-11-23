// @title Verification game instantiator
pragma solidity ^0.4.23;

import "./Decorated.sol";
import "./Instantiator.sol";
import "./PartitionInterface.sol";
import "./MMInterface.sol";
import "./MachineInterface.sol";
import "./lib/bokkypoobah/Token.sol";

contract VGInsterface is Instantiator
{
  enum state { WaitSale, WaitPartition, WaitMemoryProveValues,
               FinishedClaimerWon, FinishedChallengerWon }

  function instantiate(address _challenger, address _claimer, uint _valueXYZ,
                       uint _roundDuration, uint _salesDuration,
                       address _machineAddress, bytes32 _initialHash,
                       bytes32 _claimerFinalHash, uint _finalTime)
    public returns (uint32);
  function setChallengerPrice(uint32 _index, uint _newPrice,
                              uint _doubleDown) public;
  function setClaimerPrice(uint32 _index, uint _newPrice,
                           uint _doubleDown) public;
  function buyInstanceFromChallenger(uint32 _index) public;
  function buyInstanceFromClaimer(uint32 _index) public;
  function finishSalePhase(uint32 _index) public;
  function winByPartitionTimeout(uint32 _index) public;
  function startMachineRunChallenge(uint32 _index) public;
  function settleVerificationGame(uint32 _index) public;
  function claimVictoryByDeadline(uint32 _index) public;
  function challengerWins(uint32 _index) private;
  function claimerWins(uint32 _index) private;
  function clearInstance(uint32 _index) internal;
  function stateIsWaitSale(uint32 _index) public view;
  function stateIsWaitPartition(uint32 _index) public view returns(bool);
  function stateIsWaitMemoryProveValues(uint32 _index) public view
    returns(bool);
  function stateIsFinishedClaimerWon(uint32 _index) public view returns(bool);
  function stateIsFinishedChallengerWon(uint32 _index) public view
    returns(bool);
}
