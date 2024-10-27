class Svm::Assembler
  MOV, ADD, SUB, MUL, DIV, LOAD, STORE, JMP, JEQ, JNE, CALL, RET, PUSH, POP, INT, EXTENDED = (0..15).to_a

  OPCODES = {
    'MOV' => MOV, 'ADD' => ADD, 'SUB' => SUB, 'MUL' => MUL, 'DIV' => DIV,
    'LOAD' => LOAD, 'STORE' => STORE, 'JMP' => JMP, 'JEQ' => JEQ, 'JNE' => JNE,
    'CALL' => CALL, 'RET' => RET, 'PUSH' => PUSH, 'POP' => POP, 'INT' => INT, 'EXTENDED' => EXTENDED
  }
  
  REGISTERS = { 'R0' => 0, 'R1' => 1, 'R2' => 2, 'R3' => 3 }

  def initialize
    @labels = {}
    @machine_code = Array.new(4096, 0) # Pre-fill with 0s to accommodate ROM and program
    @current_address = 0
    @pass_two_code = []
  end

  def assemble(assembly_code)
    first_pass(assembly_code)
    second_pass
    @machine_code
  end

  def first_pass(assembly_code)
    assembly_code.each_line do |line|
      line = line.strip
      next if line.empty? || line.start_with?(';')

      if line.match?(/^[\w]+:/)
        label = line[0..-2].strip
        @labels[label] = @current_address
        next
      end

      tokens = line.split
      if tokens[0].start_with?('.')
        process_directive(tokens)
      else
        @pass_two_code << [line, @current_address]
        @current_address += 4
      end
    end
  end

  def second_pass
    @pass_two_code.each do |line, address|
      tokens = line.split
      instruction = tokens[0]
      opcode = OPCODES[instruction]
      raise "Unknown instruction #{instruction}" if opcode.nil?

      reg_x, reg_y, value = parse_operands(tokens[1..], address)
      @machine_code[address] = combine_opcode_byte(opcode, reg_x, reg_y)
      @machine_code[address + 1] = 0  # Padding byte
      @machine_code[address + 2] = (value >> 8) & 0xFF
      @machine_code[address + 3] = value & 0xFF
    end
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
    puts "operands: #{operands}"

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

    puts "reg_x: #{reg_x}, reg_y: #{reg_y}, value: #{value}"
    [reg_x, reg_y, value]
  end

  def parse_register(operand)
    reg_value = REGISTERS[operand] || raise("Invalid register: #{operand}")
    raise "Register value out of range: #{reg_value}" unless (0..3).include?(reg_value)
    reg_value
  end

  def parse_value(operand, address)
    if operand.start_with?('#')
      operand[1..-1].to_i
    elsif operand.match?(/^\d+$/)
      operand.to_i
    elsif @labels.key?(operand)
      @labels[operand]
    else
      raise "Undefined label or constant: #{operand}"
    end
  end

  def combine_opcode_byte(opcode, reg_x, reg_y)
    ((opcode << 4) & 0xF0) | ((reg_x & 0x03) << 2) | (reg_y & 0x03)
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
  JMP START
  ASM

  machine_code = assembler.assemble(assembly_code)
  puts "Machine Code: #{machine_code.compact.map { |byte| byte.to_s(16).rjust(2, '0') }}"
end

