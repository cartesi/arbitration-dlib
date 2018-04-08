/// @title Subleq interface contract
pragma solidity ^0.4.18;

import "./mortal.sol";
import "./SubleqLib.sol";

contract SubleqInterface is mortal {

  using SubleqLib for SubleqLib.SubleqCtx;
  SubleqLib.SubleqCtx subleq;

  event StepGiven(uint8 exitCode);

  // Library functions

  function SubleqInterface(address memoryManagerAddress) public
  {
    subleq.init(memoryManagerAddress);
  }

  function step() public returns (address)
  {
    return subleq.step();
  }
}

