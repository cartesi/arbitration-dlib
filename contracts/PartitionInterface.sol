/// @title Abstract interface for partition instantiator
pragma solidity ^0.4.0;

import "./Instantiator.sol";

contract PartitionInterface is Instantiator
{
  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon, DivergenceFound }

  function instantiate(address _challenger, address _claimer,
                       bytes32 _initialHash, bytes32 _claimerFinalHash,
                       uint _finalTime, uint _querySize,
                       uint _roundDuration) public returns (uint32);
  function timeHash(uint32 _index, uint key) public view returns (bytes32);
  function divergenceTime(uint32 _index) public view returns (uint);
  function stateIsWaitingQuery(uint32 _index) public view returns(bool);
  function stateIsWaitingHashes(uint32 _index) public view returns(bool);
  function stateIsChallengerWon(uint32 _index) public view returns(bool);
  function stateIsClaimerWon(uint32 _index) public view returns(bool);
  function stateIsDivergenceFound(uint32 _index) public view returns(bool);
}
