/// @title BranchInstructions
pragma solidity 0.4.24;

library BranchInstructions {
  event Print(string message);
  struct STATE_ACCESS{
  }

  STATE_ACCESS _a;

  function execute_BEQ (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    emit Print("BQE");
    //call execute_branch then:
    return rs1 == rs2;
  }

  function execute_BNE (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    emit Print("BNE");
    //call execute_branch then:
    return rs1 != rs2;
  }

}
