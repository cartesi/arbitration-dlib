/// @title Partition contract
pragma solidity ^0.4.18;

contract SimpleMemoryInstantiator {
  uint32 private currentIndex = 0;

  struct SimpleMemoryCtx {
    mapping(uint64 => bytes8) value; // value present at address
  }

  mapping(uint32 => SimpleMemoryCtx) private instance;

  function instantiate() public returns (uint) {
    currentIndex++;
    return(currentIndex - 1);
  }

  /// @notice reads a slot in memory
  /// @param _address of the desired memory
  function read(uint32 _index, uint64 _address)
    public view returns (bytes8)
  {
    require((_address & 7) == 0);
    return instance[_index].value[_address];
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param _address of the write
  /// @param _value to be written
  function write(uint32 _index, uint64 _address, bytes8 _value) public {
    require((_address & 7) == 0);
    instance[_index].value[_address] = _value;
  }

  function finishProofPhase(uint32) pure public { }

  function finishReplayPhase(uint32) pure public { }
}

