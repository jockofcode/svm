module Svm
  module InstructionSet
    # Memory and program constants
    MEMORY_SIZE = 4096
    DISPLAY_START = 128
    PROGRAM_START = 2048
    REGISTER_MASK = 0xFFFF  # 16-bit mask for registers

    # Define opcodes in an array first
    OPCODES = %w[MOV ADD SUB MUL DIV LOAD STORE JMP JEQ JNE CALL RET PUSH POP INT EXTENDED]
    
    # Create constants from the array
    OPCODES.each_with_index do |opcode, index|
      const_set(opcode, index)
    end

    def mask_opcode(opcode)
      opcode & 0x0F
    end

    def mask_register(reg)
      reg & 0x03
    end

    def shift_opcode(masked_opcode)
      masked_opcode << 4
    end

    def shift_reg_x(masked_reg)
      masked_reg << 2
    end

    def combine_opcode_byte(opcode, reg_x, reg_y)
      masked_opcode = mask_opcode(opcode)
      masked_reg_x = mask_register(reg_x)
      masked_reg_y = mask_register(reg_y)
      
      shifted_opcode = shift_opcode(masked_opcode)
      shifted_reg_x = shift_reg_x(masked_reg_x)
      
      shifted_opcode | shifted_reg_x | masked_reg_y
    end

    # Split a byte into opcode and registers
    def split_opcode_byte(byte)
      opcode = (byte & 0xF0) >> 4
      reg_x = (byte & 0x0C) >> 2
      reg_y = byte & 0x03
      [opcode, reg_x, reg_y]
    end
  end
end 