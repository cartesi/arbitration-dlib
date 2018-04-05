/// @title Subleq interface contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./SubleqLib.sol";

contract SubleqInterface is mortal {

  using SubleqLib for SubleqLib.SubleqCtx;
  SubleqLib.SubleqCtx subleq;

  event StepGiven(uint8 exitCode);

  // Library functions

  function SubleqInterface(address memoryManagerAddress,
                           uint64 theRamSize, uint64 theInputMaxSize,
                           uint64 theOutputMaxSize) public
  {
    subleq.init(memoryManagerAddress, theRamSize, theInputMaxSize,
                theOutputMaxSize);
  }

  function step() public returns (address)
  {
    return subleq.step();
  }
}

