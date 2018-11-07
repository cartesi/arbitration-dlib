/// @title BranchInstructions
pragma solidity 0.4.24;

library BranchInstructions {

  struct STATE_ACCESS{
  }

  STATE_ACCESS _a;

  function execute_BEQ (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    //call execute_branch then:
    return rs1 == rs2;
  }
}
