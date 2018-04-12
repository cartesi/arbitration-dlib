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

  function currentState() public view returns (SimpleMemoryLib.state)
  {
    return simpleMemory.currentState;
  }

  // Library functions

  function SimpleMemoryInterface() public
  {
    simpleMemory.init();
  }

  function read(uint64 _address)
    public view returns (bytes8)
  {
    return simpleMemory.read(_address);
  }

  function write(uint64 _address, bytes8 _value)
    public
  {
    simpleMemory.write(_address, _value);
  }

  function finishWritePhase() public
  {
    simpleMemory.finishWritePhase();
  }
}

