/// @title Partition contract
pragma solidity ^0.4.18;

contract mmContract {
  function read(uint64 theAddress) public view returns (bytes8);
  function write(uint64 theAddress, bytes8 theValue) public;
  function finishWritePhase() public;
}

contract mortal {
  address public owner;

  function mortal() public {
    owner = msg.sender;
  }

  function kill() public {
    if (msg.sender == owner) selfdestruct(owner);
  }
}


contract subleq is mortal {

  mmContract private memoryManager;

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

  event StepGiven(uint8 exitCode);

  function subleq(address memoryManagerAddress,
                  uint64 theRamSize, uint64 theInputMaxSize,
                  uint64 theOutputMaxSize) public
  {
    require(ramSize < 0x0000ffffffffffff);
    ramSize = theRamSize;
    inputMaxSize = theInputMaxSize;
    outputMaxSize = theOutputMaxSize;
    memoryManager = mmContract(memoryManagerAddress);
  }

  /// @notice Performs one step of the subleq machine on memory
  /// @return false indicates a halted machine or invalid instruction
  function step() public returns (uint8)
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

    pcPosition = 0x4000000000000000;
    icPosition = 0x4000000000000008;
    ocPosition = 0x4000000000000010;
    haltedState = 0x4000000000000018;
    pc = uint64(memoryManager.read(pcPosition));
    ic = uint64(memoryManager.read(icPosition));
    oc = uint64(memoryManager.read(ocPosition));
    hs = uint64(memoryManager.read(haltedState));
    memAddrA = int64(memoryManager.read(pc));
    memAddrB = int64(memoryManager.read(pc + 8));
    memAddrC = int64(memoryManager.read(pc + 16));

    // if first or second operator are < -1, throw
    if (hs != 0x0000000000000000) { StepGiven(1); return 1; }
    if (memAddrA < -1) { StepGiven(2); return 2; }
    if (memAddrB < -1) { StepGiven(3); return 3; }
    if (memAddrA == -1 && memAddrB == -1) { StepGiven(4); return 4; }
    if (memAddrA >= 0 && uint64(memAddrA) > ramSize)
       { StepGiven(5); return 5; }
    if (memAddrB >= 0 && uint64(memAddrB) > ramSize)
       { StepGiven(6); return 6; }
    // if first operator is -1, read from input
    if (memAddrA == -1) {
      // read input at ic
      bytes8 loaded = memoryManager.read(ic);
      memoryManager.write(uint64(memAddrB) * 8, loaded);
      if (ic - 0x8000000000000000 > inputMaxSize) {
        StepGiven(8); return 8;
      }
      // increment ic
      memoryManager.write(icPosition, bytes8(ic + 8));
      // increment pc by three words
      memoryManager.write(pcPosition, bytes8(pc + 24));
      memoryManager.finishWritePhase();
      StepGiven(0);
      return 0;
    }
    // if valueA is non-negative, load the memory address
    bytes8 valueA = memoryManager.read(uint64(memAddrA) * 8);
    // if first operator is positive but second operator is -1, write to output
    if (memAddrB == -1) {
      // write contents addressed by first operator into output
      memoryManager.write(oc, valueA);
      if (oc - 0xc000000000000000 > outputMaxSize) {
        StepGiven(9); return 9;
      }
      // increment oc
      memoryManager.write(ocPosition, bytes8(oc + 8));
      // increment pc by three words
      memoryManager.write(pcPosition, bytes8(pc + 24));
      memoryManager.finishWritePhase();
      if (int64(valueA) < 0) { StepGiven(1); return 1; }
      StepGiven(0);
      return 0;
    }
    // if valueB is non-negative, make the subleq operation
    bytes8 valueB = memoryManager.read(uint64(memAddrB) * 8);
    bytes8 subtraction = bytes8(int64(valueB) - int64(valueA));
    // write subtraction to memory addressed by second operator
    memoryManager.write(uint64(memAddrB) * 8, subtraction);
    if (int64(subtraction) <= 0) {
      if (memAddrC < 0) {
        // halt machine
        memoryManager.write(haltedState, 1);
        memoryManager.finishWritePhase();
        StepGiven(0);
        return 0;
      }
      if (uint64(memAddrC) > ramSize)
        { StepGiven(7); return 7; }
      memoryManager.write(pcPosition, bytes8(memAddrC * 8));
      memoryManager.finishWritePhase();
      StepGiven(0);
      return 0;
    }
  }
}
