/// @title Subleq interface contract
pragma solidity ^0.5.0;


contract MachineInterface {
    event StepGiven(uint8 exitCode);

    //function endStep(address, uint256, uint8) internal returns (uint8);

    function step(uint256) public returns (uint8);

    function getMemoryInteractor() public view returns (address);
}
