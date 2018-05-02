/// @title Subleq machine contract
pragma solidity ^0.4.18;

contract mmInstantiator {
  function read(uint32 _index, uint64 _address) public view returns (bytes8);
  function write(uint32 _index, uint64 _address, bytes8 _value) public;
  function finishReplayPhase(uint32 _index) public;
}

library SubleqLib {

  event StepGiven(uint8 exitCode);

  struct SubleqCtx {
    // use storage because of solidity's problem with locals ("Stack too deep")
    uint64 pcPosition;
    uint64 icPosition;
    uint64 ocPosition;
    uint64 hsPosition;
    uint64 rSizePosition;
    uint64 iSizePosition;
    uint64 oSizePosition;
    uint64 pc;    // program counter
    uint64 ic;    // input counter
    uint64 oc;    // output counter
    uint64 hs;    // halt state flag
    uint64 rSize; // max size of ram
    uint64 iSize; // max size of input
    uint64 oSize; // max size of output
    int64 memAddrA;
    int64 memAddrB;
    int64 memAddrC;
    uint64 ramSize;
    uint64 inputMaxSize;
    uint64 outputMaxSize;
  }

  function getAddress(SubleqCtx storage) public view returns (address)
  {
    return address(this);
  }

  function endStep(address _mmAddress, uint32 _mmIndex, uint8 _exitCode)
    internal returns (uint8) {
    mmInterface mm = mmInterface(_mmAddress);
    mm.finishReplayPhase(_mmIndex);
    emit StepGiven(_exitCode);
    return _exitCode;
  }

  /// @notice Performs one step of the subleq machine on memory
  /// @return false indicates a halted machine or invalid instruction
  function step(SubleqCtx storage self, address _mmAddress, uint32 _mmIndex)
    public returns (uint8)
  {
    // Architecture
    // +----------------+----------------+----------------+----------------+
    // | ram            | pc ic oc hs    | input          | output         |
    // |                | rs is os       |                |                |
    // +----------------+----------------+----------------+----------------+
    // Exit codes:
    // 0  - Success
    // 1  - Halted machine
    // 2  - Operator A should be -1, 0 or positive
    // 3  - Operator B should be -1, 0 or positive
    // 4  - Operators A and B cannot be both -1
    // 5  - Out of memory (addressed by operator A)
    // 6  - Out of memory (addressed by operator B)
    // 7  - Out of memory (addressed by operator C)
    // 8  - Overflow of maximum input size
    // 9  - Overflow of maximum output size
    // 10 -
    // 11 -
    // 12 -
    // 13 -
    mmInstantiator mm = mmInstantiator(_mmAddress);

    self.pcPosition = 0x4000000000000000;
    self.icPosition = 0x4000000000000008;
    self.ocPosition = 0x4000000000000010;
    self.hsPosition = 0x4000000000000018;
    self.rSizePosition = 0x4000000000000020;
    self.iSizePosition = 0x4000000000000028;
    self.oSizePosition = 0x4000000000000030;
    self.pc = uint64(mm.read(_mmIndex, self.pcPosition));
    self.ic = uint64(mm.read(_mmIndex, self.icPosition));
    self.oc = uint64(mm.read(_mmIndex, self.ocPosition));
    self.hs = uint64(mm.read(_mmIndex, self.hsPosition));
    self.rSize = uint64(mm.read(_mmIndex, self.rSizePosition));
    self.iSize = uint64(mm.read(_mmIndex, self.iSizePosition));
    self.oSize = uint64(mm.read(_mmIndex, self.oSizePosition));
    self.memAddrA = int64(mm.read(_mmIndex, self.pc));
    self.memAddrB = int64(mm.read(_mmIndex, self.pc + 8));
    self.memAddrC = int64(mm.read(_mmIndex, self.pc + 16));

    // require the sizes of ram, input and output to be reasonable
    require(self.rSize < 0x0000ffffffffffff);
    require(self.iSize < 0x0000ffffffffffff);
    require(self.oSize < 0x0000ffffffffffff);

    // if first or second operator are < -1, throw
    if (self.hs != 0x0000000000000000)
      { return(endStep(_mmAddress, _mmIndex, 1)); }
    if (self.memAddrA < -1) { return(endStep(_mmAddress, _mmIndex, 2)); }
    if (self.memAddrB < -1) { return(endStep(_mmAddress, _mmIndex, 3)); }
    if (self.memAddrA == -1 && self.memAddrB == -1)
      { return(endStep(_mmAddress, _mmIndex, 4));  }
    if (self.memAddrA >= 0 && uint64(self.memAddrA) > self.rSize)
      { return(endStep(_mmAddress, _mmIndex, 5)); }
    if (self.memAddrB >= 0 && uint64(self.memAddrB) > self.rSize)
      { return(endStep(_mmAddress, _mmIndex, 6)); }
    // if first operator is -1, read from input
    if (self.memAddrA == -1) {
      // test if input is out of range
      if (self.ic - 0x8000000000000000 > self.iSize)
        { return(endStep(_mmAddress, _mmIndex, 8)); }
      // read input at ic
      bytes8 loaded = mm.read(_mmIndex, self.ic);
      mm.write(_mmIndex, uint64(self.memAddrB) * 8, loaded);
      // increment ic
      mm.write(_mmIndex, self.icPosition, bytes8(self.ic + 8));
      // increment pc by three words
      mm.write(_mmIndex, self.pcPosition, bytes8(self.pc + 24));
      return(endStep(_mmAddress, _mmIndex, 0));
    }
    // if first operator is non-negative, load the memory address
    bytes8 valueA = mm.read(_mmIndex, uint64(self.memAddrA) * 8);
    // if first operator is non-negative, but second operator is -1,
    // write to output
    if (self.memAddrB == -1) {
      // test if output is out of range
      if (self.oc - 0xc000000000000000 > self.oSize)
        { return(endStep(_mmAddress, _mmIndex, 9)); }
      // write contents addressed by first operator into output
      mm.write(_mmIndex, self.oc, valueA);
      // increment oc
      mm.write(_mmIndex, self.ocPosition, bytes8(self.oc+ 8));
      // increment pc by three words
      mm.write(_mmIndex, self.pcPosition, bytes8(self.pc + 24));
      // cancelling this rule of halting on negative write
      // if (int64(valueA) < 0) { memoryManager.write(hsPosition, 1); }
      return(endStep(_mmAddress, _mmIndex, 0));
    }
    // if valueB is non-negative, make the subleq operation
    bytes8 valueB = mm.read(_mmIndex, uint64(self.memAddrB) * 8);
    bytes8 subtraction = bytes8(int64(valueB) - int64(valueA));
    // write subtraction to memory addressed by second operator
    mm.write(_mmIndex, uint64(self.memAddrB) * 8, subtraction);
    if (int64(subtraction) <= 0) {
      if (uint64(self.memAddrC) > self.rSize)
        { return(endStep(_mmAddress, _mmIndex, 7)); }
      if (self.memAddrC < 0) {
        // halt machine
        mm.write(_mmIndex, self.hsPosition, 1);
        return(endStep(_mmAddress, _mmIndex, 0));
      }
      mm.write(_mmIndex, self.pcPosition, bytes8(self.memAddrC * 8));
      return(endStep(_mmAddress, _mmIndex, 0));
    }
    mm.write(_mmIndex, self.pcPosition, bytes8(self.pc + 24));
    return(endStep(_mmAddress, _mmIndex, 0));
  }
}
