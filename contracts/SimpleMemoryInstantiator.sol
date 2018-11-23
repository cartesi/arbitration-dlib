/// @title Partition contract
pragma solidity 0.4.24;

import "./MMInterface.sol";

contract SimpleMemoryInstantiator is MMInterface {
  uint256 private currentIndex = 0;

  struct SimpleMemoryCtx {
    mapping(uint64 => bytes8) value; // value present at address
  }

  mapping(uint256 => SimpleMemoryCtx) private instance;

  function instantiate(address, address, bytes32) public returns (uint256)
  {
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice reads a slot in memory
  /// @param _address of the desired memory
  function read(uint256 _index, uint64 _address)
    public returns (bytes8)
  {
    require((_address & 7) == 0);
    return instance[_index].value[_address];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param _address of the write
  /// @param _value to be written
  function write(uint256 _index, uint64 _address, bytes8 _value) public {
    require((_address & 7) == 0);
    instance[_index].value[_address] = _value;
  }

  function finishProofPhase(uint256) public { }

  function finishReplayPhase(uint256) public { }

  function newHash(uint256) public view returns (bytes32)
  { require(false); }

  function stateIsWaitingProofs(uint256) public view returns(bool)
  { require(false); }

  function stateIsWaitingReplay(uint256) public view returns(bool)
  { require(false); }

  function stateIsFinishedReplay(uint256) public view returns(bool)
  { require(false); }
}
