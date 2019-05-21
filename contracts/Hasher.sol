/// @title Subleq machine contract
pragma solidity ^0.5.0;

import "./MachineInterface.sol";
import "./MMInterface.sol";

contract Hasher is MachineInterface {

  event StepGiven(uint8 exitCode);
  event Debug(bytes32 message, uint64 word);

  address mmAddress;

  constructor(address _mmAddress) public {
    mmAddress = _mmAddress;
  }

  function endStep(uint256 _mmIndex, uint8 _exitCode)
    internal returns (uint8) {
    MMInterface mm = MMInterface(mmAddress);
    mm.finishReplayPhase(_mmIndex);
    emit StepGiven(_exitCode);
    return _exitCode;
  }

  /// @notice Performs one step of the hasher machine on memory
  /// @return false indicates a halted machine or invalid instruction
  function step(uint256 _mmIndex)
    public returns (uint8)
  {
    // hasher machine simply adds to the memory initial hash :)
    MMInterface mm = MMInterface(mmAddress);
    uint64 valuePosition = 0x0000000000000000;
    uint64 value = uint64(mm.read(_mmIndex, valuePosition));
    require(value < 0xFFFFFFFFFFFFFFFF, "Overflowing machine");
    mm.write(_mmIndex, valuePosition, bytes8(value + 1));
    return(endStep(_mmIndex, 0));
  }

  function getAddress() public view returns (address)
  {
    return address(this);
  }

  function getMemoryInteractor() public view returns (address)
  {
    return(address(this));
  }
}
