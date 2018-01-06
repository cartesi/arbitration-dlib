/// @title Partition contract
pragma solidity ^0.4.18;


contract mortal {
  address public owner;

  function mortal() public {
    owner = msg.sender;
  }

  function kill() public {
    if (msg.sender == owner) {
      selfdestruct(owner);
    }
  }
}

contract testMemory is mortal {
  mapping(uint64 => bytes8) private value; // value present at address

  enum state { Writing, Reading }
  state public currentState;

  function testMemory() public
  {
    currentState = state.Writing;
  }

  /// @notice writes on a slot of memory during read and write phase
  /// @param theAddress of the write
  /// @param theValue to be written
  function write(uint64 theAddress, bytes8 theValue) public {
    require((currentState == state.Writing)
            || (currentState == state.Reading));
    require((theAddress & 7) == 0);
    value[theAddress] = theValue;
  }

  /// @notice Stop write phase and restart read phase
  function finishWritePhase() public {
    require((currentState == state.Writing)
            || (currentState == state.Reading));
    currentState = state.Reading;
  }

  /// @notice reads a slot in memory
  /// @param theAddress of the desired memory
  function read(uint64 theAddress) public view returns (bytes8) {
    require(currentState == state.Reading);
    require((theAddress & 7) == 0);
    return value[theAddress];
  }
}

