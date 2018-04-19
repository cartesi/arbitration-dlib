/// @title Partition contract
pragma solidity ^0.4.18;

library SimpleMemoryLib {

  enum state { Writing, Reading }

  struct SimpleMemoryCtx {
    mapping(uint64 => bytes8) value; // value present at address

    state currentState;
  }

  function init(SimpleMemoryCtx storage self) public
  {
    self.currentState = state.Writing;
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param _address of the write
  /// @param _value to be written
  function write(SimpleMemoryCtx storage self, uint32, uint64 _address,
                 bytes8 _value) public {
    require((self.currentState == state.Writing)
            || (self.currentState == state.Reading));
    require((_address & 7) == 0);
    self.value[_address] = _value;
  }

  /// @notice Stop write phase and restart read phase
  function finishWritePhase(SimpleMemoryCtx storage self, uint32) public
  {
    require((self.currentState == state.Writing)
            || (self.currentState == state.Reading));
    self.currentState = state.Reading;
  }

  /// @notice reads a slot in memory
  /// @param _address of the desired memory
  function read(SimpleMemoryCtx storage self, uint32, uint64 _address)
    public view returns (bytes8)
  {
    require(self.currentState == state.Reading);
    require((_address & 7) == 0);
    return self.value[_address];
  }
}

