pragma solidity 0.4.24;

contract RiscVDecoder {
  function insn_rd(uint32 code) returns(uint32){
    return (code >> 7) & 0x1F;
  }
  
  function insn_rs1(uint32 code) returns(uint32){
    return (code >> 15) & 0x1F;
  }
  
  function insn_rs2(uint32 code) returns(uint32){
    return (code >> 20) & 0x1F;
  }
  
  function insn_I_imm(uint32 code) returns(int32){
     return int32(code >> 20);
  }
  
  function insn_I_uimm(uint32 code) returns(uint32){
    return code >> 20;
  }
  
  function insn_U_imm(uint32 code) returns(int32){
    //this was a static_cast
    // return static_cast<int32_t>(insn & 0xfffff000);
    return int32(code & 0xfffff000);
  }
  
  function insn_B_imm(uint32 code) returns(int32){
    int32 imm = int32(((code >> (31 - 12)) & (1 << 12)) |
                  ((code >> (25 - 5)) & 0x7e0) |
                  ((code >> (8 - 1)) & 0x1e) |
                  ((code << (11 - 7)) & (1 << 11)));
    //int shift - cant do
    imm = (imm << 19) >> 19;
    return imm;
  }
  
  function insn_J_imm(uint32 code) returns(int32){
    int32 imm = int32(((code >> (31 - 20)) & (1 << 20)) |
                ((code >> (21 - 1)) & 0x7fe) |
                ((code >> (20 - 11)) & (1 << 11)) |
                (code & 0xff000));
    //int shift - cant do
    imm = (imm << 11) >> 11;
    return imm;
  }
  
  function insn_S_imm(uint32 code) returns(int32){
    //this was a static_cast
    // return (static_cast<int32_t>(code & 0xfe000000) >> (25 - 5)) | ((code>> 7) & 0x1F);
    return int32(((code & 0xfe000000) >> (25 - 5)) | ((code>> 7) & 0x1F));
  }

  function inst_opcode(uint32 code) returns (uint32){
    return code & 0x7F;
  }
  
  function inst_funct3(uint32 code) returns (uint32){
    return (code >> 12) & 0x07;
  }

  function insn_funct3_funct7(uint32 code) returns (uint32){
    return ((code >> 5) & 0x380) | (code >> 25);
  }
  function insn_funct3_funct5(uint32 code) returns (uint32){
    return ((code >> 7) & 0xE0) | (code >> 27);
  }
  function insn_funct7(uint32 code) returns (uint32){
    return (code >> 25) & 0x7F;
  }
  function insn_funct6(uint32 code) returns (uint32){
    return (code >> 26) & 0x3F;
  }

  function opcode(uint32 code) returns (bytes32){
    if(code < 0x002f){
      if(code < 0x0017){
        if(code < 0x000f){
          /*code is 0x0003*/
          return "load_group";
        }else if(code < 0x0013){
          /*code is 0x000f*/
          return "fence_group";
        }else {
          /*code is 0x0013*/
          return "arithmetic_immediate_group";
        }
      }else if (code > 0x0017){
        if (code < 0x0023){
          /*code is 0x001b*/
          return "arithmetic_immediate_32_group";
        }else {
          /*code is 0x0023*/
          return "store_group";
        }
      
      }else{
        /*code == 0x0017*/
        return "AUIPC";     
      } 
    }else if (code > 0x002f){
      if (code < 0x0063){
        if (code < 0x0037){
          /*code is 0x0033*/
          return "arithmetic_group";
        }else if (code > 0x0037){
          /*code is 0x003b*/
          return "arithmetic_32_group";
        }else{
          /*code == 0x0037*/
          return "LUI";
        }
      }else if (code > 0x0063){
        if(code < 0x006f){
          /*code == 0x0067*/
          return "JALR";
        }else if(code > 0x006f){
          /*code == 0x0073*/
          return "csr_env_trap_int_mm_group";
        }else {
          /*code == 0x006f*/
          return "JAL";
        }
      }else {
        /*code == 0x0063*/
        return "branch_group";
      } 
    }else{
      /*code == 0x002f*/
      return "atomic_group";
    }
  }
  
  function branch_funct3(uint32 code) returns (bytes32){
    if(code < 0x0005){
      if(code < 0x0001){
        /*code == 0x0000*/
        return "BEQ";
      }else if(code > 0x0001){
        /*code == 0x0004*/
        return "BLT";
      }else{
        /*code == 0x0001*/
        return "BNE";
      }

    }else if(code > 0x0005){
      if(code > 0x0006){
        /*code == 0x0007*/
        return "BGEU";
      }else {
        /*code == 0x0006*/
        return "BLTU";
      }
    }else{
      /*code==0x0005*/
      return "BGE";
    }
  }

  function load_funct3(uint32 code) returns (bytes32){
    if(code < 0x0003){
      if(code < 0x0001){
        /*code == 0x0000*/
        return "LB";
      }else if(code >0x0001){
        /*code == 0x0002*/
        return "LW";
      }else{
        /*code == 0x0001*/
        return "LH";
      }
    }else if(code > 0x0003){
      if(code < 0x0005){
        /*code == 0x0004*/
        return "LBU";
      }else if(code > 0x0005){
        /*code == 0x0006*/
        return "LWU";
      }else{
        /*code == 0x0005*/
        return "LHU";
      }
    }else{
      /*code == 0x0003*/
      return "LD";
    } 
  }
  
  function store_funct3(uint32 code) returns (bytes32){
    if(code < 0x0001){
      /*code == 0x0000*/
      return "SB";
    }else if(code > 0x0001){
      if(code < 0x0003){
        /*code == 0x0002*/
        return "SW";
      }else{
        /*code == 0x0003*/
        return "SD";
      }
    }else{
      /*code == 0x0001*/
      return "SH";
    }
  }

  function arithmetic_immediate_funct3(uint32 code) returns (bytes32) {
    if(code < 0x0003){
      if(code < 0x0001){
        /*code == 0x0000*/
        return "ADDI";
      }else if(code > 0x0001){
        /*code == 0x0002*/
        return "SLTI";
      }else {
        /*code == 0x0001*/
        return "SLLI";
      }
    }else if(code > 0x0003){
      if(code < 0x0006){
        if(code < 0x0005){
          /*code == 0x0004*/
          return "XORI";
        }else{
          /*code == 0x0005*/
          return "shift_right_immediate_group";
        }
      }else if(code > 0x0006){
        /*code == 0x0007*/
        return "ANDU";
      }else {
        /*code == 0x0006*/
        return "ORI";
      }
    }else {
      /*code == 0x0003*/
      return "SLTIU";
    }
  }
  
  function shift_right_immediate_funct6(uint32 code) returns (bytes32) {
    if(code < 0x0010){
      /*code == 0x0000*/
      return "SRLI";
    }else{
      /*code == 0x0010*/
      return "SRAI";
    } 
  }

  function arithmetic_immediate_32_funct3(uint32 code) returns (bytes32) {
    if(code < 0x0181){
      if(code < 0x0081){
        if(code < 0x0020){
          if(code < 0x0001){
            /*code == 0x0000*/
            return "ADD";
          }else{
            /*code == 0x0001*/
            return "MUL";
          }
        }else if(code > 0x0020){
          /*code == 0x0080*/
          return "SLL";
        }else{
          /*code == 0x0020*/
          return "SUB";
        }
      }else if(code > 0x0081){
        if(code < 0x0101){
          /*code == 0x0100*/
          return "SLT";
        }else if(code > 0x0101){
          /*code == 0x0180*/
          return "SLTU";
        }else{
          /*code == 0x0101*/
          return "MULHSU";
        }
      }else{
        /* code == 0x0081*/
        return "MULH";
      }
    }else if( code > 0x0181){
      if(code < 0x02a0){
        if(code < 0x0201){
          /*code == 0x0200*/
          return "XOR";
        }else if(code > 0x0201){
          if(code < 0x0281){
            /*code == 0x0280*/
            return "SRL";
          }else{
            /*code == 0x0281*/
            return "DIVU";
          } 
        }else {
          /*code == 0x0201*/
          return "DIV";
        }
      }else if(code > 0x02a0){
        if(code < 0x0380){
          if(code < 0x0301){
          /*code == 0x0300*/
          return "OR";
          }else{
            /*code == 0x0301*/
            return "REM";
          }
        }else if(code > 0x0380){
          /*code == 0x0381*/
          return "REMU";
        }else{
          /*code == 0x0380*/
          return "AND";
        }
      }else{
        /*code == 0x02a0*/
        return "SRA";
      }
    }else{
      /*code == 0x0181*/
      return "MULHU";
    }

  }

  function fence_group_funct3(uint32 code) returns(bytes32){
    if(code < 0x0001){
      /*code == 0x0000*/
      return "FENCE";
    }else{
      /*code == 0x0001*/
      return "FENCE_I";
    }
  }

  function env_trap_int_group_insn(uint32 code) returns (bytes32){
    if(code < 0x10200073){
      if(code < 0x100073){
        /*code == 0x0073*/
        return "ECALL";
      }else if(code > 0x100073){
        /*code == 0x200073*/
        return "URET";
      }else{
        /*code == 0x100073*/
        return "EBREAK";
      }
    }else if(code > 0x10200073){
      if(code < 0x30200073){
        /*code == 0x10500073*/
        return "WFI";
      }else{
        /*code == 0x30200073*/
        return "MRET";
      }
    }else{
      /*code = 0x10200073*/
      return "SRET";
    }
  }
  
  function csr_env_trap_int_mm_funct3(uint32 code) returns (bytes32){
    if(code < 0x0003){
      if(code < 0x0001){
        /*code == 0x0000*/
        return "env_trap_int_mm_group";
      }else if(code > 0x0001){
        /*code == 0x0002*/
        return "CSRRS";
      }else{
        /*code == 0x0001*/
        return "CSRRW";
      }
    }else if(code > 0x0003){
      if(code < 0x0006){
        /*code == 0x0005*/
        return "CSRRWI";
      }else if(code > 0x0006){
        /*code == 0x0007*/
        return "CSRRCI";
      }else{
        /*code == 0x0006*/
        return "CSRRSI";
      }
    }else{
      /*code == 0x0003*/
      return "CSRRC";
    }
  }
  function whichArithmeticImmediate32Func3(uint32 code) returns (bytes32){
    if(code < 0x0001){
      /*code == 0x0000*/
      return "ADDI";
    }else if(code > 0x0001){
      /*code == 0x0005*/
      return "shift_right_immediate_32_group";
    }else{
      /*code == 0x0001*/
      return "SLLIW";
    }
  }
  
  function whichShiftRightImmediate32Func3(uint32 code) returns (bytes32){
    if(code < 0x0020){
      /*code == 0x0000*/
      return "SRLIW";
    }else{
      /*code == 0x0020*/
      return "SRAIW";
    } 
  }
 
  function which_arithmetic_32_funct3_funct7(uint32 code) returns (bytes32){
    if(code < 0x0280){
      if(code < 0x0020){
        if(code < 0x0001){
          /*code == 0x0000*/
          return "ADDW";
        }else{
          /*code == 0x0001*/
          return "MULW";
        }
      }else if(code > 0x0020){
        if(code < 0x0201){
          /*code == 0x0080*/
          return "SLLW";
        }else{
          /*code == 0x0201*/
          return "DIVUW";
        }
      }else{
        /*code == 0x0020*/
        return "SUBW";
      }
    }else if(code > 0x0280){
      if(code < 0x0301){
        if(code < 0x02a0){
          /*code == 0x0281*/
          return "DIVUW";
        }else{
          /*code == 0x02a0*/
          return "SRAW";
        }
      }else if(code > 0x0301){
        /*code == 0x0381*/
        return "REMUW";
      }else{
        /*code == 0x0301*/
        return "REMW";
      }
    }else {
      /*code == 0x0280*/
      return "SRLW";
    }
  }

//  function getInstruction(uint32 code) returns (bytes32){
//    return opcode[code];
//  }

  function populateMaps() {
//    opcode[3] = "load_group ";
//    opcode[15] = "fence_group";
//    opcode[19] = "arithmetic_immediate_group";
//    opcode[23] = "AUIPC";
//    opcode[27] = "arithmetic_immediate_32_group";
//    opcode[35] = "store_group";
//    opcode[47] = "atomic_group";
//    opcode[51] = "arithmetic_group";
//    opcode[55] = "LUI";
//    opcode[59] = "arithmetic_32_group";
//    opcode[99] = "branch_group";
//    opcode[103] = "JALR";
//    opcode[111] = "JAL";
//    opcode[115] = "csr_env_trap_int_mm_group";
//     
//    branch_funct3[0] = "BEQ";
//    branch_funct3[1] = "BNE";
//    branch_funct3[4] = "BLT";
//    branch_funct3[5] = "BGE";
//    branch_funct3[6] = "BLTU";
//    branch_funct3[7] = "BGEU";
//  
//    load_funct3[0] = "LB";
//    load_funct3[1] = "LH";
//    load_funct3[2] = "LW";
//    load_funct3[3] = "LD";
//    load_funct3[4] = "LBU";
//    load_funct3[5] = "LHU";
//    load_funct3[6] = "LWU";
//
//    store_funct3[0] = "SB";
//    store_funct3[1] = "SH";
//    store_funct3[2] = "SW";
//    store_funct3[3] = "SD";
//
//    arithmetic_immediate_funct3[0] = "ADDI";
//    arithmetic_immediate_funct3[1] = "SLLI";
//    arithmetic_immediate_funct3[2] = "SLTI";
//    arithmetic_immediate_funct3[3] = "SLTIU";
//    arithmetic_immediate_funct3[4] = "XORI";
//    arithmetic_immediate_funct3[6] = "ORI";
//    arithmetic_immediate_funct3[7] = "ANDI";
//
//    arithmetic_immediate_funct3[5] = "shift_right_immediate_group";
//
//    shift_right_immediate_funct6[0] = "SRLI";
//    shift_right_immediate_funct6[16] = "SRAI";
//
//    arithmetic_funct3_funct7[0] = "ADD";
//    arithmetic_funct3_funct7[1] = "MUL";
//    arithmetic_funct3_funct7[32] = "SUB";
//    arithmetic_funct3_funct7[128] = "SLL";
//    arithmetic_funct3_funct7[129] = "MULH";
//    arithmetic_funct3_funct7[256] = "SLT";
//    arithmetic_funct3_funct7[257] = "MULHSU";
//    arithmetic_funct3_funct7[384] = "SLTU";
//    arithmetic_funct3_funct7[385] = "MULHU";
//    arithmetic_funct3_funct7[512] = "XOR";
//    arithmetic_funct3_funct7[513] = "DIV";
//    arithmetic_funct3_funct7[640] = "SRL";
//    arithmetic_funct3_funct7[641] = "DIVU";
//    arithmetic_funct3_funct7[672] = "SRA";
//    arithmetic_funct3_funct7[768] = "OR";
//    arithmetic_funct3_funct7[769] = "REM";
//    arithmetic_funct3_funct7[896] = "AND";
//    arithmetic_funct3_funct7[897] = "REMU";
//    
//    fence_group_funct3[0] = "FENCE";
//    fence_group_funct3[1] = "FENCE_I";
//
//    env_trap_int_group_insn[115] = "ECALL";
//    env_trap_int_group_insn[1048691] = "EBREAK";
//    env_trap_int_group_insn[2097267] = "URET";
//    env_trap_int_group_insn[270532723] = "SRET";
//    env_trap_int_group_insn[273678451] = "WFI";
//    env_trap_int_group_insn[807403635] = "MRET";
//
//    csr_env_trap_int_mm_funct3[1] = "CSRRW";
//    csr_env_trap_int_mm_funct3[2] = "CSRRS";
//    csr_env_trap_int_mm_funct3[3] = "CSRRC";
//    csr_env_trap_int_mm_funct3[5] = "CSRRWI";
//    csr_env_trap_int_mm_funct3[6] = "CSRRSI";
//    csr_env_trap_int_mm_funct3[7] = "CSRRCI";
//                               
//    csr_env_trap_int_mm_funct3[0] = "env_trap_int_mm_group";
//
//    arithmetic_immediate_32_funct3[0] = "ADDI";
//    arithmetic_immediate_32_funct3[1] = "SLLIW";
//
//    arithmetic_immediate_32_funct3[5] = "shift_right_immediate_32_group";
//
//    shift_right_immediate_32_funct7[0] = "SRLIW";
//    shift_right_immediate_32_funct7[32] = "SRAIW";
//
//    arithmetic_32_funct3_funct7[0] = "ADDW ";
//    arithmetic_32_funct3_funct7[1] = "MULW ";
//    arithmetic_32_funct3_funct7[32] = "SUBW ";
//    arithmetic_32_funct3_funct7[128] = "SLLW ";
//    arithmetic_32_funct3_funct7[513] = "DIVW ";
//    arithmetic_32_funct3_funct7[640] = "SRLW ";
//    arithmetic_32_funct3_funct7[641] = "DIVUW";
//    arithmetic_32_funct3_funct7[672] = "SRAW ";
//    arithmetic_32_funct3_funct7[769] = "REMW ";
//    arithmetic_32_funct3_funct7[897] = "REMUW";
 }
}
