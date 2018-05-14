/// @title Interface for memory manager instantiator
pragma solidity ^0.4.0;

import "./Instantiator.sol";

contract MMInterface is Instantiator
{
  enum state { WaitingProofs, WaitingReplay, FinishedReplay }

  function newHash(uint32 _index) public view returns (bytes32);
  function instantiate(address _provider, address _client,
                       bytes32 _initialHash) public returns (uint32);
  function stateIsWaitingProofs(uint32 _index) public view returns(bool);
  function stateIsWaitingReplay(uint32 _index) public view returns(bool);
  function stateIsFinishedReplay(uint32 _index) public view returns(bool);
}
