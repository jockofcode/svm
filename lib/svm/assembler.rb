require_relative 'instruction_set'

class Svm::Assembler
  include Svm::InstructionSet

  # Use constants from InstructionSet instead of VirtualMachine
  REGISTERS = { 'R0' => 0, 'R1' => 1, 'R2' => 2, 'R3' => 3 }
  
  # Create hash mapping of instruction names to opcodes
  OPCODE_MAP = OPCODES.each_with_object({}) do |name, hash| 
    hash[name] = const_get(name)
  end

  def initialize
    @machine_code = Array.new(MEMORY_SIZE, 0)
    @labels = {}
    @current_address = PROGRAM_START
    @pass_two_code = []
  end

  def assemble(assembly_code)
    first_pass(assembly_code)
    second_pass
    @machine_code
  end

  def first_pass(assembly_code)
    assembly_code.each_line do |line|
      process_line(line.strip)
    end
  end

  def process_line(line)
    return if skip_line?(line)
    return process_label(line) if label_line?(line)
    process_code_line(line)
  end

  def process_code_line(line)
    tokens = line.split
    return process_directive(tokens) if directive_line?(tokens)
    process_instruction(line)
  end

  def skip_line?(line)
    line.empty? || line.start_with?(';')
  end

  def label_line?(line)
    line.match?(/^[\w]+:/)
  end

  def process_label(line)
    label = line.split(':').first.strip
    @labels[label] = @current_address
  end

  def directive_line?(tokens)
    tokens[0].start_with?('.')
  end

  def process_instruction(line)
    @pass_two_code << [line, @current_address]
    @current_address += 4
  end

  def second_pass
    @pass_two_code.each do |line, address|
      instruction = extract_instruction(line)
      next if instruction.empty?

      @current_address = address
      generate_machine_code(instruction, address)
    end
  end

  def extract_instruction(line)
    line.split(';').first.strip
  end

  def generate_machine_code(instruction, address)
    opcode, operands = parse_instruction(instruction)
    validate_opcode!(opcode)
    
    @current_instruction = opcode  # Track current instruction
    opcode_value = OPCODE_MAP[opcode]
    reg_x, reg_y, value = parse_operands(operands, address)
    @current_instruction = nil  # Clear after parsing
    
    @machine_code[address] = combine_opcode_byte(opcode_value, reg_x, reg_y)
    @machine_code[address + 1] = 0x00
    @machine_code[address + 2] = (value >> 8) & 0xFF
    @machine_code[address + 3] = value & 0xFF
  end

  def parse_instruction(instruction)
    parts = instruction.split(/\s*,\s*|\s+/)
    [parts[0], parts[1..]]
  end

  def validate_opcode!(opcode)
    raise "Unknown instruction #{opcode}" unless OPCODE_MAP.key?(opcode)
  end

  def write_instruction_to_memory(address, opcode, reg_x, reg_y, value)
    @machine_code[address] = combine_opcode_byte(opcode, reg_x, reg_y)
    @machine_code[address + 1] = 0x00  # Reserved byte
    @machine_code[address + 2] = (value >> 8) & 0xFF
    @machine_code[address + 3] = value & 0xFF
  end

  def process_directive(tokens)
    directive = tokens[0]
    case directive
    when '.org'
      @current_address = tokens[1].to_i
    when '.const'
      label = tokens[1]
      value = tokens[2].to_i
      @labels[label] = value
    when '.data'
      size = tokens[1].to_i
      @current_address += size
    else
      raise "Unknown directive #{directive}"
    end
  end

  def parse_operands(operands, address)
    reg_x = reg_y = value = 0

    operands = operands.map { |op| op.gsub(',', '') }

    if operands.size == 1
      value = parse_value(operands[0], address)
    elsif operands.size == 2
      reg_x = parse_register(operands[0])
      if REGISTERS.key?(operands[1])
        reg_y = parse_register(operands[1])
      else
        value = parse_value(operands[1], address)
      end
    elsif operands.size == 3
      reg_x = parse_register(operands[0])
      reg_y = parse_register(operands[1])
      value = parse_value(operands[2], address)
    end

    [reg_x, reg_y, value]
  end

  def parse_register(operand)
    reg_value = REGISTERS[operand] || raise("Invalid register: #{operand}")
    raise "Register value out of range: #{reg_value}" unless (0..3).include?(reg_value)
    reg_value
  end

  def parse_value(operand, address)
    return operand.to_i if operand =~ /^\d+$/
    return operand[1..-1].to_i if operand.start_with?('#')
    
    if @labels.key?(operand)
      target_address = @labels[operand]
      
      # For jump instructions, calculate relative offset
      if @current_instruction && [:JMP, :JEQ, :JNE, :CALL].include?(@current_instruction.to_sym)
        # Add 4 to address to account for instruction size when calculating offset
        offset = target_address - (address + 4)
        return offset
      end
      
      return target_address
    end
    
    raise "Undefined label or constant: #{operand}"
  end
end

def example_assembler_call
  # Usage
  assembler = Assembler.new

  assembly_code = <<~ASM
  ; ROM code at address 0
  .org 0
  JMP START

  ; Main program at address 2049
  .org 2049
START:
  MOV R0, #10
  MOV R1, #14
  ADD R0, R1
  STORE R0, RESULT

RESULT:
  .data 1
  INT #0    ; Halt instead of looping
  ASM

  machine_code = assembler.assemble(assembly_code)
  puts "Machine Code: #{machine_code.compact.map { |byte| byte.to_s(16).rjust(2, '0') }}"
end
