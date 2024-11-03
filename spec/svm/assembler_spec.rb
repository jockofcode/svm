require 'spec_helper'
require 'svm/assembler'

RSpec.describe Svm::Assembler do
  let(:assembler) { Svm::Assembler.new }

  describe '#assemble' do
    it 'assembles a simple program' do
      assembly_code = <<~ASM
        MOV R0, #10
        MOV R1, #20
        ADD R0, R1
        STORE R0, 100
      ASM

      machine_code = assembler.assemble(assembly_code)

      expect(machine_code[Svm::Assembler::PROGRAM_START..Svm::Assembler::PROGRAM_START+15]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 0, 0), 0x00, 0x00, 0x0A,  # MOV R0, #10
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 1, 0), 0x00, 0x00, 0x14,  # MOV R1, #20
        assembler.combine_opcode_byte(Svm::InstructionSet::ADD, 0, 1), 0x00, 0x00, 0x00,  # ADD R0, R1
        assembler.combine_opcode_byte(Svm::InstructionSet::STORE, 0, 0), 0x00, 0x00, 0x64  # STORE R0, 100
      ])
    end

    it 'handles labels correctly' do
      assembly_code = <<~ASM
        .org 0
        JMP START       ; Jump forward to START
        MOV R1, #10    ; This instruction should be skipped
        START:
        MOV R0, #5     ; This is where we land
        JMP END        ; Jump forward to END
        MOV R1, #20    ; This instruction should be skipped
        END:
        INT #0         ; Halt
      ASM

      machine_code = assembler.assemble(assembly_code)

      expect(machine_code[0..15]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::JMP, 0, 0), 0x00, 0x00, 0x04,  # JMP +4 (forward to START)
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 1, 0), 0x00, 0x00, 0x0A,  # MOV R1, #10 (skipped)
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 0, 0), 0x00, 0x00, 0x05,  # MOV R0, #5 (START)
        assembler.combine_opcode_byte(Svm::InstructionSet::JMP, 0, 0), 0x00, 0x00, 0x04   # JMP +4 (forward to END)
      ])
    end

    it 'processes directives correctly' do
      assembly_code = <<~ASM
        .org 100
        MOV R0, #1
        .const FIVE 5
        MOV R1, FIVE
      ASM

      machine_code = assembler.assemble(assembly_code)

      expect(machine_code[100..107]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 0, 0), 0x00, 0x00, 0x01,  # MOV R0, #1
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 1, 0), 0x00, 0x00, 0x05   # MOV R1, #5 (FIVE constant)
      ])
    end

    it 'correctly assembles an ADD instruction' do
      assembly_code = ".org 0\nADD R0, R1"
      machine_code = assembler.assemble(assembly_code)

      expect(machine_code[0..3]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::ADD, 0, 1), 0x00, 0x00, 0x00  # ADD R0, R1
      ])
    end
  end

  describe '#first_pass' do
    it 'processes labels and directives correctly' do
      assembly_code = <<~ASM
        START:
        MOV R0, #10
        .org #{Svm::VirtualMachine::PROGRAM_START + 100}
        LABEL:
        ADD R0, R1
      ASM

      assembler.send(:first_pass, assembly_code)

      expect(assembler.instance_variable_get(:@labels)).to include(
        'START' => Svm::VirtualMachine::PROGRAM_START, 
        'LABEL' => Svm::VirtualMachine::PROGRAM_START + 100
      )
    end
  end

  describe '#second_pass' do
    it 'generates correct machine code' do
      assembler.instance_variable_set(:@pass_two_code, [
        ['MOV R0, #10', 0],
        ['ADD R0, R1', 4]
      ])
      assembler.instance_variable_set(:@labels, {})

      assembler.send(:second_pass)

      machine_code = assembler.instance_variable_get(:@machine_code)
      expect(machine_code[0..7]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::MOV, 0, 0), 0x00, 0x00, 0x0A,
        assembler.combine_opcode_byte(Svm::InstructionSet::ADD, 0, 1), 0x00, 0x00, 0x00
      ])
    end
  end

  describe '#process_directive' do
    it 'handles .org directive' do
      assembler.send(:process_directive, ['.org', '100'])
      expect(assembler.instance_variable_get(:@current_address)).to eq(100)
    end

    it 'handles .const directive' do
      assembler.send(:process_directive, ['.const', 'FIVE', '5'])
      expect(assembler.instance_variable_get(:@labels)['FIVE']).to eq(5)
    end

    it 'handles .data directive' do
      assembler.instance_variable_set(:@current_address, 0)
      assembler.send(:process_directive, ['.data', '4'])
      expect(assembler.instance_variable_get(:@current_address)).to eq(4)
    end

    it 'raises error for unknown directive' do
      expect { assembler.send(:process_directive, ['.unknown', '100']) }.to raise_error(RuntimeError, "Unknown directive .unknown")
    end
  end

  describe '#parse_operands' do
    it 'parses single operand' do
      result = assembler.send(:parse_operands, ['#10'], 0)
      expect(result).to eq([0, 0, 10])
    end

    it 'parses two operands with register and immediate value' do
      result = assembler.send(:parse_operands, ['R0', '#20'], 0)
      expect(result).to eq([0, 0, 20])
    end

    it 'parses two operands with two registers' do
      result = assembler.send(:parse_operands, ['R0', 'R1'], 0)
      expect(result).to eq([0, 1, 0])
    end

    it 'parses three operands' do
      result = assembler.send(:parse_operands, ['R0', 'R1', '#30'], 0)
      expect(result).to eq([0, 1, 30])
    end
  end

  describe '#parse_register' do
    it 'parses valid register' do
      expect(assembler.send(:parse_register, 'R2')).to eq(2)
    end

    it 'raises error for invalid register' do
      expect { assembler.send(:parse_register, 'R5') }.to raise_error(RuntimeError, "Invalid register: R5")
    end
  end

  describe '#parse_value' do
    before do
      assembler.instance_variable_set(:@labels, {'CONST' => 42})
    end

    it 'parses immediate value' do
      expect(assembler.send(:parse_value, '#10', 0)).to eq(10)
    end

    it 'parses numeric value' do
      expect(assembler.send(:parse_value, '20', 0)).to eq(20)
    end

    it 'parses label value' do
      expect(assembler.send(:parse_value, 'CONST', 0)).to eq(42)
    end

    it 'raises error for undefined label' do
      expect { assembler.send(:parse_value, 'UNDEFINED', 0) }.to raise_error(RuntimeError, "Undefined label or constant: UNDEFINED")
    end
  end

  describe '#combine_opcode_byte' do
    it 'correctly combines ADD opcode with registers' do
      opcode = Svm::InstructionSet::ADD
      reg_x = 0  # R0
      reg_y = 1  # R1

      result = assembler.send(:combine_opcode_byte, opcode, reg_x, reg_y)

      expect(result).to eq(0x21)  # 0010 0001 in binary
    end

    it 'handles different register combinations for ADD' do
      opcode = Svm::InstructionSet::ADD
      expect(assembler.send(:combine_opcode_byte, opcode, 0, 0)).to eq(0x20)  # ADD R0, R0
      expect(assembler.send(:combine_opcode_byte, opcode, 1, 2)).to eq(0x26)  # ADD R1, R2
      expect(assembler.send(:combine_opcode_byte, opcode, 3, 1)).to eq(0x2D)  # ADD R3, R1
    end
  end

  describe '#defines_all_expected_opcodes_as_constants' do
    it 'defines all expected opcodes as constants' do
      expected_opcodes = %w[INT MOV ADD SUB MUL DIV LOAD STORE JMP JEQ JNE CALL RET PUSH POP EXTENDED]
      
      expected_opcodes.each_with_index do |opcode, index|
        expect(Svm::InstructionSet.const_get(opcode)).to eq(index)
      end
    end

    it 'assigns sequential values starting from 0' do
      expect(Svm::InstructionSet::INT).to eq(0)
      expect(Svm::InstructionSet::MOV).to eq(1)
      expect(Svm::InstructionSet::ADD).to eq(2)
      expect(Svm::InstructionSet::EXTENDED).to eq(15)
    end
  end

  describe 'relative jumps' do
    it 'generates correct forward relative jumps' do
      assembly_code = <<~ASM
        .org 0
        MOV R0, #10
        JMP FORWARD
        MOV R0, #20      ; Should be skipped
        FORWARD:
        INT #1
      ASM

      machine_code = assembler.assemble(assembly_code)
      
      expect(machine_code[4..7]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::JMP, 0, 0), 0x00, 0x00, 0x04  # JMP +4 (skip next instruction)
      ])
    end

    it 'generates correct backward relative jumps' do
      assembly_code = <<~ASM
        .org 0
        START:
        MOV R0, #10
        SUB R0, #1
        JNE R0, R0, START  ; Jump back to START when R0 != 0
      ASM

      machine_code = assembler.assemble(assembly_code)
      
      expect(machine_code[8..11]).to eq([
        assembler.combine_opcode_byte(Svm::InstructionSet::JNE, 0, 0), 0x00, 0xFF, 0xF4  # JNE -12 (jump back to START)
      ])
    end
  end
end
