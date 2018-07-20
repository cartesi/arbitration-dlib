/// @title Subleq interface contract
pragma solidity ^0.4.24;

contract MachineInterface
{
  event StepGiven(uint8 exitCode);

  function endStep(address, uint32, uint8) internal returns (uint8);

  function step(address, uint32) public returns (uint8);
}
