require_relative 'instruction_set'
require_relative 'socket_tty_connection'

class Svm::VirtualMachine 
  include Svm::InstructionSet

  attr_accessor :debug, :debug_output, :memory, :registers, :PC, :SP, :running, :consecutive_mov_r0_0

  def initialize
    @memory_size = MEMORY_SIZE
    @debug = false
    @debug_output = $stdout
    @memory = Array.new(@memory_size, 0)
    @registers = Array.new(4, 0)
    @PC = PROGRAM_START
    @SP = MEMORY_SIZE - 1
    @running = true
    @consecutive_mov_r0_0 = 0
    @instruction_limit = nil
    @instruction_count = 0
    @tty = Svm::SocketTtyConnection.new
  end

  def enable_debug(output = $stdout)
    @debug = true
    @debug_output = output
  end

  def disable_debug
    @debug = false
    @debug_output = $stdout
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
      @instruction_count += 1
      
      if @instruction_limit && @instruction_count >= @instruction_limit
        @running = false
        raise "Instruction limit reached: #{@instruction_limit} instructions executed"
      end
    end
  end

  def execute_instruction
    instruction_pc = @PC  # Store initial PC value
    instruction = @memory[@PC..@PC + 3]
    opcode_byte = @memory[@PC]
    opcode, reg_x, reg_y = split_opcode_byte(opcode_byte)
    immediate_value = (@memory[@PC + 2] << 8) | @memory[@PC + 3]

    debug_instruction(opcode, reg_x, reg_y, immediate_value)

    # Check for MOV R0, #0
    if opcode == MOV && reg_x == 0 && reg_y == 0 && immediate_value == 0
      @consecutive_mov_r0_0 += 1
      raise "Running blank code detected: MOV R0, #0 executed #{@consecutive_mov_r0_0} times consecutively" if @consecutive_mov_r0_0 > 1
    else
      @consecutive_mov_r0_0 = 0
    end

    case opcode
    when INT
      handle_interrupt(immediate_value)
    when MOV
      value = reg_y.zero? ? immediate_value : @registers[reg_y]
      @registers[reg_x] = value & REGISTER_MASK
    when ADD
      @registers[reg_x] = ((@registers[reg_x] & REGISTER_MASK) + (@registers[reg_y] & REGISTER_MASK)) & REGISTER_MASK
    when SUB
      @registers[reg_x] = (@registers[reg_x] - @registers[reg_y]) & REGISTER_MASK
    when MUL
      @registers[reg_x] = (@registers[reg_x] * @registers[reg_y]) & REGISTER_MASK
    when DIV
      @registers[reg_x] = (@registers[reg_x] / @registers[reg_y]) & REGISTER_MASK unless @registers[reg_y].zero?
    when LOAD
      @registers[reg_x] = @memory[immediate_value] & REGISTER_MASK
    when STORE
      @memory[immediate_value] = @registers[reg_x] & REGISTER_MASK
    when JMP
      @PC = calculate_relative_jump(@PC, immediate_value)
      return
    when JEQ
      if @registers[reg_x] == @registers[reg_y]
        @PC = calculate_relative_jump(@PC, immediate_value)
        return
      end
    when JNE
      if @registers[reg_x] != @registers[reg_y]
        @PC = calculate_relative_jump(@PC, immediate_value)
      else
        @PC += 4
      end
    when CALL
      push_word(@PC + 4)
      @PC = immediate_value
      return
    when RET
      @PC = pop_word
      return
    when PUSH
      push_word(@registers[reg_x])
    when POP
      @registers[reg_x] = pop_word
    when EXTENDED
      return
    end

    @PC += 4 unless @PC != instruction_pc
    @running = false if @PC >= MEMORY_SIZE
  end

  # Stack operations
  # Interrupt handler (basic I/O)
  def handle_interrupt(number)
    case number
    when 0  # Halt
      @running = false
    when 1  # Output
      puts "Output: #{@registers[0]}"
    when 2  # TTY Input
      if @tty&.byte_available?
        @registers[0] = @tty.read_byte
      else
        @registers[0] = 0
        sleep 0.01  # Add small sleep to prevent tight loop
      end
    when 3  # TTY Output
      @tty&.write_byte(@registers[0])
    else
      raise "Unknown interrupt: #{number}"
    end
  end

  def debug_instruction(opcode, reg_x, reg_y, immediate_value)
    return unless @debug

    instruction = case opcode
    when MOV
      reg_y.zero? ? "MOV R#{reg_x}, ##{immediate_value}" : "MOV R#{reg_x}, R#{reg_y}"
    when ADD
      "ADD R#{reg_x}, R#{reg_y}"
    when SUB
      reg_y.zero? ? "SUB R#{reg_x}, ##{immediate_value}" : "SUB R#{reg_x}, R#{reg_y}"
    when MUL
      "MUL R#{reg_x}, R#{reg_y}"
    when DIV
      "DIV R#{reg_x}, R#{reg_y}"
    when LOAD
      "LOAD R#{reg_x}, #{immediate_value}"
    when STORE
      "STORE R#{reg_x}, #{immediate_value}"
    when JMP
      "JMP #{format_relative_jump(immediate_value)}"
    when JEQ
      "JEQ R#{reg_x}, R#{reg_y}, #{format_relative_jump(immediate_value)}"
    when JNE
      "JNE R#{reg_x}, R#{reg_y}, #{format_relative_jump(immediate_value)}"
    when CALL
      "CALL #{immediate_value}"
    when RET
      "RET"
    when PUSH
      "PUSH R#{reg_x}"
    when POP
      "POP R#{reg_x}"
    when INT
      "INT ##{immediate_value}"
    else
      "UNKNOWN"
    end

    debug_line = "PC: #{@PC.to_s(16).rjust(4, '0')} | #{instruction} | R0=#{@registers[0]} R1=#{@registers[1]} R2=#{@registers[2]} R3=#{@registers[3]}"
    
    case @debug_output
    when String  # Treat as filename
      File.open(@debug_output, 'a') { |f| f.puts(debug_line) }
    when Proc
      @debug_output.call(debug_line)
    else  # Assume it's an IO object (like $stdout)
      @debug_output.puts(debug_line)
    end
  end

  def push_word(value)
    @SP -= 1
    @memory[@SP] = value & REGISTER_MASK
  end

  def pop_word
    value = @memory[@SP] & REGISTER_MASK
    @SP += 1
    value
  end

  def calculate_relative_jump(current_pc, offset)
    # Convert unsigned 16-bit to signed using helper method
    signed_offset = unsigned_to_signed_16bit(offset)
    # Remove the +4 offset to make JMP +0 jump to itself
    new_pc = current_pc + signed_offset
    new_pc
  end

  def set_instruction_limit(limit)
    @instruction_limit = limit
    @instruction_count = 0
  end

  def clear_instruction_limit
    @instruction_limit = nil
    @instruction_count = 0
  end

  def start_tty
    @tty.start
  end

  def stop_tty
    @tty.stop
  end

  private

  def unsigned_to_signed_16bit(value)
    # Convert unsigned 16-bit to signed by checking the sign bit
    # and subtracting 2^16 if it's set
    (value & 0x7FFF) - (value & 0x8000)
  end

  def format_relative_jump(offset)
    # Convert unsigned 16-bit to signed using helper method
    signed_offset = unsigned_to_signed_16bit(offset)
    signed_offset >= 0 ? "+#{signed_offset}" : signed_offset.to_s
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

