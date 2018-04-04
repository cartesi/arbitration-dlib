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
  /// @param theAddress of the write
  /// @param theValue to be written
  function write(SimpleMemoryCtx storage self, uint64 theAddress,
                 bytes8 theValue) public {
    require((self.currentState == state.Writing)
            || (self.currentState == state.Reading));
    require((theAddress & 7) == 0);
    self.value[theAddress] = theValue;
  }

  /// @notice Stop write phase and restart read phase
  function finishWritePhase(SimpleMemoryCtx storage self) public
  {
    require((self.currentState == state.Writing)
            || (self.currentState == state.Reading));
    self.currentState = state.Reading;
  }

  /// @notice reads a slot in memory
  /// @param theAddress of the desired memory
  function read(SimpleMemoryCtx storage self, uint64 theAddress)
    public view returns (bytes8)
  {
    require(self.currentState == state.Reading);
    require((theAddress & 7) == 0);
    return self.value[theAddress];
  }
}

