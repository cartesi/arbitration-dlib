/// @title RiscVDecoder
pragma solidity 0.4.24;

contract RiscVDecoder {
  // Contract responsible for decoding the riscv's instructions
  // It applies different bitwise operations and masks to reach
  // specific positions and use that positions to identify the
  // correct function to be executed

  /// @notice Get the instruction's RD
  //  @param insn Instruction
  function insn_rd(uint32 insn) public pure returns(uint32){
    return (insn >> 7) & 0x1F;
  }

  /// @notice Get the instruction's RS1
  //  @param insn Instruction
  function insn_rs1(uint32 insn) public pure returns(uint32){
    return (insn >> 15) & 0x1F;
  }

  /// @notice Get the instruction's RS2
  //  @param insn Instruction
  function insn_rs2(uint32 insn) public pure returns(uint32){
    return (insn >> 20) & 0x1F;
  }

  /// @notice Get the I-type instruction's immediate value
  //  @param insn Instruction
  function insn_I_imm(uint32 insn) public pure returns(int32){
     return int32(insn >> 20);
  }

  /// @notice Get the I-type instruction's unsigned immediate value
  //  @param insn Instruction
  function insn_I_uimm(uint32 insn) public pure returns(uint32){
    return insn >> 20;
  }

  /// @notice Get the U-type instruction's immediate value
  //  @param insn Instruction
  function insn_U_imm(uint32 insn) public pure returns(int32){
    //this was a static_cast
    // return static_cast<int32_t>(insn & 0xfffff000);
    return int32(insn & 0xfffff000);
  }

  /// @notice Get the B-type instruction's immediate value
  //  @param insn Instruction
  function insn_B_imm(uint32 insn) public pure returns(int32){
    int32 imm = int32(((insn >> (31 - 12)) & (1 << 12)) |
                  ((insn >> (25 - 5)) & 0x7e0) |
                  ((insn >> (8 - 1)) & 0x1e) |
                  ((insn << (11 - 7)) & (1 << 11)));
    //TO-DO: use arithmetic shift on BitManipulation library
    //int shift - cant do
    imm = (imm << 19) >> 19;
    return imm;
  }

  /// @notice Get the J-type instruction's immediate value
  //  @param insn Instruction
  function insn_J_imm(uint32 insn) public pure returns(int32){
    int32 imm = int32(((insn >> (31 - 20)) & (1 << 20)) |
                ((insn >> (21 - 1)) & 0x7fe) |
                ((insn >> (20 - 11)) & (1 << 11)) |
                (insn & 0xff000));
    //TO-DO: use arithmetic shift on BitManipulation library
    //int shift - cant do
    imm = (imm << 11) >> 11;
    return imm;
  }

  /// @notice Get the S-type instruction's immediate value
  //  @param insn Instruction
  function insn_S_imm(uint32 insn) public pure returns(int32){
    //this was a static_cast
    // return (static_cast<int32_t>(insn & 0xfe000000) >> (25 - 5)) | ((insn>> 7) & 0x1F);
    return int32(((insn & 0xfe000000) >> (25 - 5)) | ((insn>> 7) & 0x1F));
  }

  /// @notice Get the instruction's opcode field
  //  @param insn Instruction
  function inst_opinsn(uint32 insn) public pure returns (uint32){
    return insn & 0x7F;
  }

  /// @notice Get the instruction's funct3 field
  //  @param insn Instruction
  function inst_funct3(uint32 insn) public pure returns (uint32){
    return (insn >> 12) & 0x07;
  }

  /// @notice Get the concatenation of instruction's funct3 and funct7 fields
  //  @param insn Instruction
  function insn_funct3_funct7(uint32 insn) public pure returns (uint32){
    return ((insn >> 5) & 0x380) | (insn >> 25);
  }

  /// @notice Get the concatenation of instruction's funct3 and funct5 fields
  //  @param insn Instruction
  function insn_funct3_funct5(uint32 insn) public pure returns (uint32){
    return ((insn >> 7) & 0xE0) | (insn >> 27);
  }

  /// @notice Get the instruction's funct7 field
  //  @param insn Instruction
  function insn_funct7(uint32 insn) public pure returns (uint32){
    return (insn >> 25) & 0x7F;
  }

  /// @notice Get the instruction's funct6 field
  //  @param insn Instruction
  function insn_funct6(uint32 insn) public pure returns (uint32){
    return (insn >> 26) & 0x3F;
  }

  function opinsn(uint32 insn) public pure returns (bytes32){
    if(insn < 0x002f){
      if(insn < 0x0017){
        if(insn == 0x0003){
          /*insn is 0x0003*/
          return "load_group";
        }else if(insn == 0x000f){
          /*insn is 0x000f*/
          return "fence_group";
        }else if(insn == 0x0013){
          /*insn is 0x0013*/
          return "arithmetic_immediate_group";
        }
      }else if (insn > 0x0017){
        if (insn == 0x001b){
          /*insn is 0x001b*/
          return "arithmetic_immediate_32_group";
        }else if(insn == 0x0023){
          /*insn is 0x0023*/
          return "store_group";
        }
      }else if(insn == 0x0017){
        /*insn == 0x0017*/
        return "AUIPC";
      }
    }else if (insn > 0x002f){
      if (insn < 0x0063){
        if (insn == 0x0033){
          /*insn is 0x0033*/
          return "arithmetic_group";
        }else if (insn == 0x003b){
          /*insn is 0x003b*/
          return "arithmetic_32_group";
        }else if(insn == 0x0037){
          /*insn == 0x0037*/
          return "LUI";
        }
      }else if (insn > 0x0063){
        if(insn == 0x0067){
          /*insn == 0x0067*/
          return "JALR";
        }else if(insn == 0x0073){
          /*insn == 0x0073*/
          return "csr_env_trap_int_mm_group";
        }else if(insn == 0x006f){
          /*insn == 0x006f*/
          return "JAL";
        }
      }else if (insn == 0x0063){
        /*insn == 0x0063*/
        return "branch_group";
      }
    }else if(insn == 0x002f){
      /*insn == 0x002f*/
      return "atomic_group";
    }
    return "illegal insn";
  }

  function branch_funct3(uint32 insn) public pure returns (bytes32){
    if(insn < 0x0005){
      if(insn == 0x0000){
        /*insn == 0x0000*/
        return "BEQ";
      }else if(insn == 0x0004){
        /*insn == 0x0004*/
        return "BLT";
      }else if(insn == 0x0001){
        /*insn == 0x0001*/
        return "BNE";
      }
    }else if(insn > 0x0005){
      if(insn == 0x0007){
        /*insn == 0x0007*/
        return "BGEU";
      }else if(insn == 0x006){
        /*insn == 0x0006*/
        return "BLTU";
      }
    }else if(insn == 0x0005){
      /*insn==0x0005*/
      return "BGE";
    }
    return "illegal insn";
  }

  function load_funct3(uint32 insn) public pure returns (bytes32){
    if(insn < 0x0003){
      if(insn == 0x0000){
        /*insn == 0x0000*/
        return "LB";
      }else if(insn == 0x0002){
        /*insn == 0x0002*/
        return "LW";
      }else if(insn == 0x0001){
        /*insn == 0x0001*/
        return "LH";
      }
    }else if(insn > 0x0003){
      if(insn == 0x0004){
        /*insn == 0x0004*/
        return "LBU";
      }else if(insn == 0x0006){
        /*insn == 0x0006*/
        return "LWU";
      }else if(insn == 0x0005){
        /*insn == 0x0005*/
        return "LHU";
      }
    }else if(insn == 0x0003){
      /*insn == 0x0003*/
      return "LD";
    }
    return "illegal insn";
  }

  function store_funct3(uint32 insn) public pure returns (bytes32){
    if(insn == 0x0000){
      /*insn == 0x0000*/
      return "SB";
    }else if(insn > 0x0001){
      if(insn == 0x0002){
        /*insn == 0x0002*/
        return "SW";
      }else if(insn == 0x0003){
        /*insn == 0x0003*/
        return "SD";
      }
    }else if(insn == 0x0001){
      /*insn == 0x0001*/
      return "SH";
    }
    return "illegal insn";
  }

  function arithmetic_immediate_funct3(uint32 insn) public pure returns (bytes32) {
    if(insn < 0x0003){
      if(insn == 0x0000){
        /*insn == 0x0000*/
        return "ADDI";
      }else if(insn == 0x0002){
        /*insn == 0x0002*/
        return "SLTI";
      }else if(insn == 0x0001){
        /*insn == 0x0001*/
        return "SLLI";
      }
    }else if(insn > 0x0003){
      if(insn < 0x0006){
        if(insn == 0x0004){
          /*insn == 0x0004*/
          return "XORI";
        }else if(insn == 0x0005){
          /*insn == 0x0005*/
          return "shift_right_immediate_group";
        }
      }else if(insn == 0x0007){
        /*insn == 0x0007*/
        return "ANDU";
      }else if(insn == 0x0006){
        /*insn == 0x0006*/
        return "ORI";
      }
    }else if(insn == 0x0003){
      /*insn == 0x0003*/
      return "SLTIU";
    }
    return "illegal insn";
  }

  function shift_right_immediate_funct6(uint32 insn) public pure returns (bytes32) {
    if(insn == 0x0000){
      /*insn == 0x0000*/
      return "SRLI";
    }else if(insn == 0x0010){
      /*insn == 0x0010*/
      return "SRAI";
    }
    return "illegal insn";
  }

  function arithmetic_immediate_32_funct3(uint32 insn) public pure returns (bytes32) {
    if(insn < 0x0181){
      if(insn < 0x0081){
        if(insn < 0x0020){
          if(insn == 0x0000){
            /*insn == 0x0000*/
            return "ADD";
          }else if(insn == 0x0001){
            /*insn == 0x0001*/
            return "MUL";
          }
        }else if(insn == 0x0080){
          /*insn == 0x0080*/
          return "SLL";
        }else if(insn == 0x0020){
          /*insn == 0x0020*/
          return "SUB";
        }
      }else if(insn > 0x0081){
        if(insn == 0x0100){
          /*insn == 0x0100*/
          return "SLT";
        }else if(insn == 0x0180){
          /*insn == 0x0180*/
          return "SLTU";
        }else if(insn == 0x0101){
          /*insn == 0x0101*/
          return "MULHSU";
        }
      }else if(insn == 0x0081){
        /* insn == 0x0081*/
        return "MULH";
      }
    }else if(insn > 0x0181){
      if(insn < 0x02a0){
        if(insn == 0x0200){
          /*insn == 0x0200*/
          return "XOR";
        }else if(insn > 0x0201){
          if(insn ==  0x0280){
            /*insn == 0x0280*/
            return "SRL";
          }else if(insn == 0x0281){
            /*insn == 0x0281*/
            return "DIVU";
          }
        }else if(insn == 0x0201){
          /*insn == 0x0201*/
          return "DIV";
        }
      }else if(insn > 0x02a0){
        if(insn < 0x0380){
          if(insn == 0x0300){
          /*insn == 0x0300*/
          return "OR";
          }else if(insn == 0x0301){
            /*insn == 0x0301*/
            return "REM";
          }
        }else if(insn == 0x0381){
          /*insn == 0x0381*/
          return "REMU";
        }else if(insn == 0x380){
          /*insn == 0x0380*/
          return "AND";
        }
      }else if(insn == 0x02a0){
        /*insn == 0x02a0*/
        return "SRA";
      }
    }else if(insn == 0x0181){
      /*insn == 0x0181*/
      return "MULHU";
    }
    return "illegal insn";
  }

  function fence_group_funct3(uint32 insn) public pure returns(bytes32){
    if(insn == 0x0000){
      /*insn == 0x0000*/
      return "FENCE";
    }else if(insn == 0x0001){
      /*insn == 0x0001*/
      return "FENCE_I";
    }
    return "illegal insn";
  }

  function env_trap_int_group_insn(uint32 insn) public pure returns (bytes32){
    if(insn < 0x10200073){
      if(insn == 0x0073){
        /*insn == 0x0073*/
        return "ECALL";
      }else if(insn == 0x200073){
        /*insn == 0x200073*/
        return "URET";
      }else if(insn == 0x100073){
        /*insn == 0x100073*/
        return "EBREAK";
      }
    }else if(insn > 0x10200073){
      if(insn == 0x10500073){
        /*insn == 0x10500073*/
        return "WFI";
      }else if(insn == 0x30200073){
        /*insn == 0x30200073*/
        return "MRET";
      }
    }else if(insn == 0x10200073){
      /*insn = 0x10200073*/
      return "SRET";
    }
    return "illegal expression";
  }

  function csr_env_trap_int_mm_funct3(uint32 insn) public pure returns (bytes32){
    if(insn < 0x0003){
      if(insn == 0x0000){
        /*insn == 0x0000*/
        return "env_trap_int_mm_group";
      }else if(insn ==  0x0002){
        /*insn == 0x0002*/
        return "CSRRS";
      }else if(insn == 0x0001){
        /*insn == 0x0001*/
        return "CSRRW";
      }
    }else if(insn > 0x0003){
      if(insn == 0x0005){
        /*insn == 0x0005*/
        return "CSRRWI";
      }else if(insn == 0x0007){
        /*insn == 0x0007*/
        return "CSRRCI";
      }else if(insn == 0x0006){
        /*insn == 0x0006*/
        return "CSRRSI";
      }
    }else if(insn == 0x0003){
      /*insn == 0x0003*/
      return "CSRRC";
    }
    return "illegal insn";
  }
  function whichArithmeticImmediate32Func3(uint32 insn) public pure returns (bytes32){
    if(insn == 0x0000){
      /*insn == 0x0000*/
      return "ADDI";
    }else if(insn ==  0x0005){
      /*insn == 0x0005*/
      return "shift_right_immediate_32_group";
    }else if(insn == 0x0001){
      /*insn == 0x0001*/
      return "SLLIW";
    }
    return "illegal insn";
  }

  function whichShiftRightImmediate32Func3(uint32 insn) public pure returns (bytes32){
    if(insn == 0x0000){
      /*insn == 0x0000*/
      return "SRLIW";
    }else if(insn == 0x0020){
      /*insn == 0x0020*/
      return "SRAIW";
    }
    return "illegal insn";
  }

  function which_arithmetic_32_funct3_funct7(uint32 insn) public pure returns (bytes32){
    if(insn < 0x0280){
      if(insn < 0x0020){
        if(insn == 0x0000){
          /*insn == 0x0000*/
          return "ADDW";
        }else if(insn == 0x0001){
          /*insn == 0x0001*/
          return "MULW";
        }
      }else if(insn > 0x0020){
        if(insn == 0x0080){
          /*insn == 0x0080*/
          return "SLLW";
        }else if(insn == 0x0201){
          /*insn == 0x0201*/
          return "DIVUW";
        }
      }else if(insn == 0x0020){
        /*insn == 0x0020*/
        return "SUBW";
      }
    }else if(insn > 0x0280){
      if(insn < 0x0301){
        if(insn == 0x0281){
          /*insn == 0x0281*/
          return "DIVUW";
        }else if(insn == 0x02a0){
          /*insn == 0x02a0*/
          return "SRAW";
        }
      }else if(insn == 0x0381){
        /*insn == 0x0381*/
        return "REMUW";
      }else if(insn == 0x0301){
        /*insn == 0x0301*/
        return "REMW";
      }
    }else if(insn == 0x0280) {
      /*insn == 0x0280*/
      return "SRLW";
    }
    return "illegal insn";
  }
}
