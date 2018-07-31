/// @title Abstract interface for partition instantiator
pragma solidity 0.4.24;

import "./Instantiator.sol";

contract PartitionInterface is Instantiator
{
  enum state { WaitingQuery, WaitingHashes,
               ChallengerWon, ClaimerWon, DivergenceFound }

  function instantiate(address _challenger, address _claimer,
                       bytes32 _initialHash, bytes32 _claimerFinalHash,
                       uint _finalTime, uint _querySize,
                       uint _roundDuration) public returns (uint256);
  function timeHash(uint256 _index, uint key) public view returns (bytes32);
  function divergenceTime(uint256 _index) public view returns (uint);
  function stateIsWaitingQuery(uint256 _index) public view returns(bool);
  function stateIsWaitingHashes(uint256 _index) public view returns(bool);
  function stateIsChallengerWon(uint256 _index) public view returns(bool);
  function stateIsClaimerWon(uint256 _index) public view returns(bool);
  function stateIsDivergenceFound(uint256 _index) public view returns(bool);
}
