/// @title Subleq machine contract
pragma solidity ^0.4.18;

contract mmContract {
  function read(uint64 theAddress) public view returns (bytes8);
  function write(uint64 theAddress, bytes8 theValue) public;
  function finishWritePhase() public;
}

library subleqLib {

  event StepGiven(uint8 exitCode);

  struct subleqCtx {
    mmContract memoryManager;
    address owner;

    // use storage because of solidity's problem with locals ("Stack too deep")
    uint64 pcPosition;
    uint64 icPosition;
    uint64 ocPosition;
    uint64 haltedState;
    uint64 pc;
    uint64 ic;
    uint64 oc;
    uint64 hs;
    int64 memAddrA;
    int64 memAddrB;
    int64 memAddrC;
    uint64 ramSize;
    uint64 inputMaxSize;
    uint64 outputMaxSize;
  }

  function init(subleqCtx storage self, address memoryManagerAddress,
                uint64 theRamSize, uint64 theInputMaxSize,
                uint64 theOutputMaxSize) public
  {
    require(theRamSize < 0x0000ffffffffffff);
    self.ramSize = theRamSize;
    self.inputMaxSize = theInputMaxSize;
    self.outputMaxSize = theOutputMaxSize;
    self.memoryManager = mmContract(memoryManagerAddress);
  }

  /// @notice Performs one step of the subleq machine on memory
  /// @return false indicates a halted machine or invalid instruction
  function step(subleqCtx storage self) public returns (uint8)
  {
    // Architecture
    // +----------------+----------------+----------------+----------------+
    // | ram            | pc ic oc       | input          | output         |
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
    self.haltedState = 0x4000000000000018;
    self.pc = uint64(self.memoryManager.read(self.pcPosition));
    self.ic = uint64(self.memoryManager.read(self.icPosition));
    self.oc = uint64(self.memoryManager.read(self.ocPosition));
    self.hs = uint64(self.memoryManager.read(self.haltedState));
    self.memAddrA = int64(self.memoryManager.read(self.pc));
    self.memAddrB = int64(self.memoryManager.read(self.pc + 8));
    self.memAddrC = int64(self.memoryManager.read(self.pc + 16));

    // if first or second operator are < -1, throw
    if (self.hs != 0x0000000000000000) { emit StepGiven(1); return 1; }
    if (self.memAddrA < -1) { emit StepGiven(2); return 2; }
    if (self.memAddrB < -1) { emit StepGiven(3); return 3; }
    if (self.memAddrA == -1 && self.memAddrB == -1)
      { emit StepGiven(4); return 4; }
    if (self.memAddrA >= 0 && uint64(self.memAddrA) > self.ramSize)
       { emit StepGiven(5); return 5; }
    if (self.memAddrB >= 0 && uint64(self.memAddrB) > self.ramSize)
       { emit StepGiven(6); return 6; }
    // if first operator is -1, read from input
    if (self.memAddrA == -1) {
      // test if input is out of range
      if (self.ic - 0x8000000000000000 > self.inputMaxSize) {
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
      if (self.oc - 0xc000000000000000 > self.outputMaxSize) {
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
      // if (int64(valueA) < 0) { memoryManager.write(haltedState, 1); }
      emit StepGiven(0);
      return 0;
    }
    // if valueB is non-negative, make the subleq operation
    bytes8 valueB = self.memoryManager.read(uint64(self.memAddrB) * 8);
    bytes8 subtraction = bytes8(int64(valueB) - int64(valueA));
    // write subtraction to memory addressed by second operator
    self.memoryManager.write(uint64(self.memAddrB) * 8, subtraction);
    if (int64(subtraction) <= 0) {
      if (uint64(self.memAddrC) > self.ramSize) { emit StepGiven(7); return 7; }
      if (self.memAddrC < 0) {
        // halt machine
        self.memoryManager.write(self.haltedState, 1);
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
