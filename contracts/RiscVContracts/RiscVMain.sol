// @title RiscVMain
pragma solidity 0.4.24;

import "./RiscVDecoder.sol";
import "./RiscVMachineState.sol";

contract RiscVMain is RiscVDecoder {
  // Main RiscV contract - should be able to receive a machine state, receive the
  //next instruction and perform the step function following RiscV defined behaviour

  //this shouldnt be in storage - too expensive. How can we have this in memory
  //and access it without passing by param (only accepted on experimental pragma)
  RiscVMachineState.Machine_state a;

  function execute_branch(uint64 pc, uint32 insn){
    uint64 rs1 = 5; //read_register rs1
    uint64 rs2 = 5; //read_register rs2

    if(branch_funct3(insn, rs1, rs2)){
      uint64 new_pc = uint64(int32(pc) + insn_B_imm(insn));
      if((new_pc & 3) != 0) {
        //return misaligned_fetch_exception;
      }else {
        //return execute_jump(a, new_pc);
      }
    }
//    should this be done on the blockchain?
//    return execute_next_insn(a, pc);
  }
}
