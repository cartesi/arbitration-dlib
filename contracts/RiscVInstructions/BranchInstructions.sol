/// @title BranchInstructions
pragma solidity 0.4.24;

library BranchInstructions {
  event Print(string message);

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

  function execute_BLT (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    emit Print("BLT");
    //call execute_branch then:
    return int64(rs1) < int64(rs2);
  }

  function execute_BGE (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    emit Print("BGE");
    //call execute_branch then:
    return int64(rs1) >= int64(rs2);
  }

  function execute_BLTU (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    emit Print("BLTU");
    //call execute_branch then:
    return rs1 < rs2;
  }

  function execute_BGEU (uint64 pc, uint32 insn, uint64 rs1, uint64 rs2)
  public returns (bool)
  {
    emit Print("BGEU");
    //call execute_branch then:
    return rs1 >= rs2;
  }
}
