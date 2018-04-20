/// @title Interface for memory manager instantiator
pragma solidity ^0.4.0;

contract MMInterface
{
  enum state { WaitingValues, Reading, Writing, UpdatingHashes,
               FinishedUpdating }

  function newHash(uint32 _index) public view returns (bytes32);
  function currentState(uint32 _index) public view returns (state);
  function instantiate(address _provider, address _client,
                       bytes32 _initialHash) public returns (uint32);
}
