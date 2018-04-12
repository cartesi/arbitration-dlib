/// @title Subleq machine contract
pragma solidity ^0.4.18;

contract mmContract {
  function read(uint64 _address) public view returns (bytes8);
  function write(uint64 _address, bytes8 _value) public;
  function finishWritePhase() public;
}

library SubleqLib {

  event StepGiven(uint8 exitCode);

  struct SubleqCtx {
    mmContract memoryManager;
    address owner;

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

  function init(SubleqCtx storage self, address memoryManagerAddress) public
  {
    self.owner = msg.sender;
    self.memoryManager = mmContract(memoryManagerAddress);
  }

  function getAddress(SubleqCtx storage) public view returns (address)
  {
    return address(this);
  }

  /// @notice Performs one step of the subleq machine on memory
  /// @return false indicates a halted machine or invalid instruction
  function step(SubleqCtx storage self) public returns (uint8)
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
    require(msg.sender == self.owner);

    self.pcPosition = 0x4000000000000000;
    self.icPosition = 0x4000000000000008;
    self.ocPosition = 0x4000000000000010;
    self.hsPosition = 0x4000000000000018;
    self.rSizePosition = 0x4000000000000020;
    self.iSizePosition = 0x4000000000000028;
    self.oSizePosition = 0x4000000000000030;
    self.pc = uint64(self.memoryManager.read(self.pcPosition));
    self.ic = uint64(self.memoryManager.read(self.icPosition));
    self.oc = uint64(self.memoryManager.read(self.ocPosition));
    self.hs = uint64(self.memoryManager.read(self.hsPosition));
    self.rSize = uint64(self.memoryManager.read(self.rSizePosition));
    self.iSize = uint64(self.memoryManager.read(self.iSizePosition));
    self.oSize = uint64(self.memoryManager.read(self.oSizePosition));
    self.memAddrA = int64(self.memoryManager.read(self.pc));
    self.memAddrB = int64(self.memoryManager.read(self.pc + 8));
    self.memAddrC = int64(self.memoryManager.read(self.pc + 16));

    // require the sizes of ram, input and output to be reasonable
    require(self.rSize < 0x0000ffffffffffff);
    require(self.iSize < 0x0000ffffffffffff);
    require(self.oSize < 0x0000ffffffffffff);

    // if first or second operator are < -1, throw
    if (self.hs != 0x0000000000000000) { emit StepGiven(1); return 1; }
    if (self.memAddrA < -1) { emit StepGiven(2); return 2; }
    if (self.memAddrB < -1) { emit StepGiven(3); return 3; }
    if (self.memAddrA == -1 && self.memAddrB == -1)
      { emit StepGiven(4); return 4; }
    if (self.memAddrA >= 0 && uint64(self.memAddrA) > self.rSize)
       { emit StepGiven(5); return 5; }
    if (self.memAddrB >= 0 && uint64(self.memAddrB) > self.rSize)
       { emit StepGiven(6); return 6; }
    // if first operator is -1, read from input
    if (self.memAddrA == -1) {
      // test if input is out of range
      if (self.ic - 0x8000000000000000 > self.iSize) {
        emit StepGiven(8); return 8;
      }
      // read input at ic
      bytes8 loaded = self.memoryManager.read(self.ic);
      self.memoryManager.write(uint64(self.memAddrB) * 8, loaded);
      // increment ic
      self.memoryManager.write(self.icPosition, bytes8(self.ic + 8));
      // increment pc by three words
      self.memoryManager.write(self.pcPosition, bytes8(self.pc + 24));
      self.memoryManager.finishWritePhase();
      emit StepGiven(0);
      return 0;
    }
    // if first operator is non-negative, load the memory address
    bytes8 valueA = self.memoryManager.read(uint64(self.memAddrA) * 8);
    // if first operator is non-negative, but second operator is -1,
    // write to output
    if (self.memAddrB == -1) {
      // test if output is out of range
      if (self.oc - 0xc000000000000000 > self.oSize) {
        emit StepGiven(9); return 9;
      }
      // write contents addressed by first operator into output
      self.memoryManager.write(self.oc, valueA);
      // increment oc
      self.memoryManager.write(self.ocPosition, bytes8(self.oc+ 8));
      // increment pc by three words
      self.memoryManager.write(self.pcPosition, bytes8(self.pc + 24));
      self.memoryManager.finishWritePhase();
      // cancelling this rule of halting on negative write
      // if (int64(valueA) < 0) { memoryManager.write(hsPosition, 1); }
      emit StepGiven(0);
      return 0;
    }
    // if valueB is non-negative, make the subleq operation
    bytes8 valueB = self.memoryManager.read(uint64(self.memAddrB) * 8);
    bytes8 subtraction = bytes8(int64(valueB) - int64(valueA));
    // write subtraction to memory addressed by second operator
    self.memoryManager.write(uint64(self.memAddrB) * 8, subtraction);
    if (int64(subtraction) <= 0) {
      if (uint64(self.memAddrC) > self.rSize) { emit StepGiven(7); return 7; }
      if (self.memAddrC < 0) {
        // halt machine
        self.memoryManager.write(self.hsPosition, 1);
        self.memoryManager.finishWritePhase();
        emit StepGiven(0);
        return 0;
      }
      self.memoryManager.write(self.pcPosition, bytes8(self.memAddrC * 8));
      self.memoryManager.finishWritePhase();
      emit StepGiven(0);
      return 0;
    }
    self.memoryManager.write(self.pcPosition, bytes8(self.pc + 24));
    emit StepGiven(0);
    return 0;
  }
}
