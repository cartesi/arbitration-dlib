/// @title Memory manager contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./SimpleMemoryLib.sol";

contract SimpleMemoryInterface is mortal {

  using SimpleMemoryLib for SimpleMemoryLib.SimpleMemoryCtx;
  SimpleMemoryLib.SimpleMemoryCtx simpleMemory;

  // Getters methods

  function value(uint64 key) public view returns (bytes8) {
    return simpleMemory.value[key];
  }

  // Library functions

  function SimpleMemoryInterface() public
  {
    simpleMemory.init();
  }

  function read(uint64 theAddress)
    public view returns (bytes8)
  {
    return simpleMemory.read(theAddress);
  }

  function write(uint64 theAddress, bytes8 theValue)
    public
  {
    simpleMemory.write(theAddress, theValue);
  }

  function finishWritePhase() public
  {
    simpleMemory.finishWritePhase();
  }
}

