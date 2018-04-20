/// @title Subleq interface contract
pragma solidity ^0.4.18;

import "./SubleqLib.sol";

contract SubleqInterface
{
  using SubleqLib for SubleqLib.SubleqCtx;
  SubleqLib.SubleqCtx subleq;

  event StepGiven(uint8 exitCode);

  // Library functions

  //function SubleqInterface(address memoryManagerAddress) public
  // {
    //subleq.init(memoryManagerAddress);
  //}

  function step(address _mm, uint32 _index) public returns (address)
  {
    return subleq.step(_mm, _index);
  }
}
