/// @title Partition contract
pragma solidity 0.5;

import "./MMInterface.sol";

contract SimpleMemoryInstantiator is MMInterface {
  uint256 private currentIndex = 0;

  struct SimpleMemoryCtx {
    mapping(uint64 => uint64) value; // value present at address
  }

  mapping(uint256 => SimpleMemoryCtx) private instance;

  function instantiate(address, address, bytes32) public returns (uint256)
  {
    active[currentIndex] = true;
    return(currentIndex++);
  }

  /// @notice reads a slot in memory
  /// @param _address of the desired memory
  function read(uint256 _index, uint64 _address) public
    returns (uint64)
  {
    require((_address & 7) == 0);
    return instance[_index].value[_address];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param _address of the write
  /// @param _value to be written
  function write(uint256 _index, uint64 _address, uint64 _value) public
  {
    require((_address & 7) == 0);
    instance[_index].value[_address] = _value;
  }

  function newHash(uint256) public view returns (bytes32)
  { require(false); }

  function finishProofPhase(uint256) public {}

  function finishReplayPhase(uint256) public {}

  function stateIsWaitingProofs(uint256) public view returns(bool)
  { require(false);
    return(true);
  }

  function stateIsWaitingReplay(uint256) public view returns(bool)
  {
    require(false);
    return(true);
  }

  function stateIsFinishedReplay(uint256) public view returns(bool)
  {
    require(false);
    return(true);
  }

  function isConcerned(uint256, address) public view returns(bool)
  {
    return(true);
  }
}
