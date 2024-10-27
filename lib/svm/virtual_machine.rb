class Svm::VirtualMachine 
  # Constants for memory size and instruction codes
  MEMORY_SIZE = 4096
  DISPLAY_START = 129
  PROGRAM_START = 2048
  REGISTER_MASK = 0xFFFF  # 16-bit mask for registers

  # Instruction set
  MOV, ADD, SUB, MUL, DIV, LOAD, STORE, JMP, JEQ, JNE, CALL, RET, PUSH, POP, INT, EXTENDED = (0..15).to_a
  attr_accessor :debug

  def initialize
    @debug = false
    @memory = Array.new(MEMORY_SIZE, 0)      # Memory array
    @registers = Array.new(4, 0)             # Registers R0..R3 (16-bit each)
    @PC = PROGRAM_START                      # Program Counter
    @SP = MEMORY_SIZE - 1                    # Stack Pointer initialized at end of memory
    @running = true                          # Flag to keep VM running
  end

  # Load program into memory at a specified address
  def load_program(program, start_address = PROGRAM_START)
    program.each_with_index { |byte, index| @memory[start_address + index] = byte }
  end

  # Run the VM, fetching and executing instructions
  def run(start_address = PROGRAM_START)
    @PC = start_address
    while @running
      execute_instruction
    end
  end

  def execute_instruction
    instruction_pc = @PC  # Store initial PC value
    instruction = @memory[@PC..@PC + 3]
    opcode_byte = @memory[@PC]
    binding.irb if debug
    opcode, reg_x, reg_y = split_opcode_byte(opcode_byte)
    immediate_value = (@memory[@PC + 2] << 8) | @memory[@PC + 3]

    case opcode
    when MOV
      value = reg_y.zero? ? immediate_value : @registers[reg_y]
      @registers[reg_x] = value & REGISTER_MASK
    when ADD
      @registers[reg_x] = (@registers[reg_x] + @registers[reg_y]) & REGISTER_MASK
    when SUB
      @registers[reg_x] = (@registers[reg_x] - @registers[reg_y]) & REGISTER_MASK
    when MUL
      @registers[reg_x] = (@registers[reg_x] * @registers[reg_y]) & REGISTER_MASK
    when DIV
      @registers[reg_x] = (@registers[reg_x] / @registers[reg_y]) & REGISTER_MASK unless @registers[reg_y].zero?
    when LOAD
      high_byte = @memory[immediate_value]
      low_byte = @memory[immediate_value + 1]
      @registers[reg_x] = ((high_byte << 8) | low_byte) & REGISTER_MASK
    when STORE
      @memory[immediate_value] = (@registers[reg_x] >> 8) & 0xFF
      @memory[immediate_value + 1] = @registers[reg_x] & 0xFF
    when JMP
      @PC = immediate_value
      return
    when JEQ
      if @registers[reg_x] == @registers[reg_y]
        @PC = immediate_value
        return
      end
    when JNE
      if @registers[reg_x] != @registers[reg_y]
        @PC = immediate_value
        return
      end
    when CALL
      push(@PC + 4)
      @PC = immediate_value
      return
    when RET
      @PC = pop
      return
    when PUSH
      push_word(@registers[reg_x])
    when POP
      @registers[reg_x] = pop_word
    when INT
      handle_interrupt(immediate_value)
    when EXTENDED
      @running = false
      return
    end

    @PC += 4 unless @PC != instruction_pc
    @running = false if @PC >= MEMORY_SIZE
  end

  # Stack operations
  def push(value)
    push_word(value)  # Use push_word for all stack operations
  end

  def pop
    pop_word  # Use pop_word for all stack operations
  end

  # Interrupt handler (basic I/O)
  def handle_interrupt(code)
    case code
    when 1
      puts "Output: #{@registers[0]}"
    else
      raise "Unknown interrupt: #{code}"
    end
  end

  def split_opcode_byte(byte)
binding.irb if (byte & 0xF0) == false
    opcode = (byte & 0xF0) >> 4
    reg_x = (byte & 0x0C) >> 2
    reg_y = byte & 0x03
    [opcode, reg_x, reg_y]
  end

  def combine_opcode_byte(opcode, reg_x, reg_y)
    ((opcode & 0x0F) << 4) | ((reg_x & 0x03) << 2) | (reg_y & 0x03)
  end

  # Modified stack operations for 16-bit values
  def push_word(value)
    value = value & REGISTER_MASK  # Ensure 16-bit value
    @SP -= 2
    @memory[@SP + 1] = (value >> 8) & 0xFF  # Store high byte
    @memory[@SP + 2] = value & 0xFF         # Store low byte
  end

  def pop_word
    high_byte = @memory[@SP + 1]
    low_byte = @memory[@SP + 2]
    @SP += 2
    ((high_byte << 8) | low_byte) & REGISTER_MASK
  end
end

# # Example usage
# 
# vm = Svm::VirtualMachine.new
# 
# # Example program to add 10 and 14 and store the result at DISPLAY_START (129)
# program = [
#   0x00, 0x00, 0x00, 0x0A,  # MOV R0, 10
#   0x01, 0x00, 0x00, 0x0E,  # MOV R1, 14
#   0x10, 0x00, 0x00, 0x00,  # ADD R0, R1
#   0x60, 0x00, 0x00, 0x81,  # STORE R0, 129
#   0x07, 0x00, 0x08, 0x01   # JMP to loop or HALT (placeholder)
# ]
# 
# vm.load_program(program)
# vm.run
# 
# # Output display memory result
# puts "Display Result at 129: #{vm.instance_variable_get(:@memory)[DISPLAY_START]}"
# 

