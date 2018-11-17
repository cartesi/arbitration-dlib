// @title RiscVMain
pragma solidity 0.4.24;

import "./RiscVDecoder.sol";
import "./RiscVMachineState.sol";

contract RiscVMain is RiscVDecoder {
  // Main RiscV contract - should be able to receive a machine state, receive the
  //next instruction and perform the step function following RiscV defined behaviour

  //event to help debbuging
  event Print(string message);
  event Print(uint64 uintToPrint);

  enum execute_status {
    illegal,
    retired
  }
  //this shouldnt be in storage - too expensive. How can we have this in memory
  //and access it without passing by param (only accepted on experimental pragma)
  RiscVMachineState.Machine_state a;

  function execute_branch(uint64 pc, uint32 insn) returns (execute_status){
    //does this work? If yes, why?
    uint64 rs1 = a.x[insn_rs1(insn)]; //read_register rs1
    uint64 rs2 = a.x[insn_rs2(insn)]; //read_register rs2

    emit Print(rs1);
    emit Print(rs2);

    if(branch_funct3(insn, rs1, rs2)){
      uint64 new_pc = uint64(int32(pc) + insn_B_imm(insn));
      if((new_pc & 3) != 0) {
        return execute_status.illegal;
        //return misaligned_fetch_exception;
      }else {
        return execute_status.illegal;
        //return execute_jump(a, new_pc);
      }
    }
//    should this be done on the blockchain?
        return execute_status.illegal;
//    return execute_next_insn(a, pc);
  }
}
