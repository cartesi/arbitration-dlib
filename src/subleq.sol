/// @title Partition contract
pragma solidity ^0.4.18;

contract mmContract {
  function read(uint64 theAddress) public view returns (bytes8);
  function finishReadPhase() public;
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

  event StepGiven(bool success);

  function subleq(address memoryManagerAddress) public
  {
    memoryManager = mmContract(memoryManagerAddress);
  }

  /// @notice Performs one step of the subleq machine on memory
  /// @return false indicates a halted machine or invalid instruction
  function step() public returns (bool)
  {
    // +----------------+----------------+----------------+----------------+
    // | hd             | pc ic oc       | input          | output         |
    // +----------------+----------------+----------------+----------------+
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
    if (hs != 0x0000000000000000) { StepGiven(false); return false; }
    if (memAddrA < -1) { StepGiven(false); return false; }
    if (memAddrB < -1) { StepGiven(false); return false; }
    if (memAddrA == -1 && memAddrB == -1) { StepGiven(false); return false; }
    if (memAddrA >= 0 && uint64(memAddrA) > 0x0000ffffffffffff)
       { StepGiven(false); return false; }
    if (memAddrB >= 0 && uint64(memAddrB) > 0x0000ffffffffffff)
       { StepGiven(false); return false; }
    // if first operator is -1, read from input
    if (memAddrA == -1) {
      // read input at ic
      bytes8 loaded = memoryManager.read(ic);
      memoryManager.finishReadPhase();
      memoryManager.write(uint64(memAddrB) * 8, loaded);
      // increment ic
      memoryManager.write(icPosition, bytes8(ic + 8));
      // increment pc by three words
      memoryManager.write(pcPosition, bytes8(pc + 24));
      memoryManager.finishWritePhase();
      StepGiven(true);
      return true;
    }
    // if valueA is non-negative, load the memory address
    bytes8 valueA = memoryManager.read(uint64(memAddrA) * 8);
    // if first operator is positive but second operator is -1, write to output
    if (memAddrB == -1) {
      // write contents addressed by first operator into output
      memoryManager.finishReadPhase();
      memoryManager.write(oc, valueA);
      // increment oc
      memoryManager.write(ocPosition, bytes8(oc + 8));
      // increment pc by three words
      memoryManager.write(pcPosition, bytes8(pc + 24));
      memoryManager.finishWritePhase();
      if (int64(valueA) < 0) { StepGiven(false); return false; }
      StepGiven(true);
      return true;
    }
    // if valueB is non-negative, make the subleq operation
    bytes8 valueB = memoryManager.read(uint64(memAddrB) * 8);
    bytes8 subtraction = bytes8(int64(valueB) - int64(valueA));
    // write subtraction to memory addressed by second operator
    memoryManager.finishReadPhase();
    memoryManager.write(uint64(memAddrB) * 8, subtraction);
    if (int64(subtraction) <= 0) {
      if (memAddrC < 0) {
        // halt machine
        memoryManager.write(haltedState, 1);
        memoryManager.finishWritePhase();
        StepGiven(true);
        return true;
      }
      if (uint64(memAddrC) > 0x0000ffffffffffff)
        { StepGiven(false); return false; }
      memoryManager.write(pcPosition, bytes8(memAddrC * 8));
      memoryManager.finishWritePhase();
      StepGiven(true);
      return true;
    }
  }
}
