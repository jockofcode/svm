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

      expect(machine_code[0..15]).to eq([
        0x00, 0x00, 0x00, 0x0A,  # MOV R0, #10
        0x04, 0x00, 0x00, 0x14,  # MOV R1, #20
        0x11, 0x00, 0x00, 0x00,  # ADD R0, R1 (0001 0001)
        0x60, 0x00, 0x00, 0x64   # STORE R0, 100
      ])
    end

    it 'handles labels correctly' do
      assembly_code = <<~ASM
        JMP START
        START:
        MOV R0, #5
        JMP START
      ASM

      machine_code = assembler.assemble(assembly_code)

      expect(machine_code[0..11]).to eq([
        0x70, 0x00, 0x00, 0x04,  # JMP START (address 4)
        0x00, 0x00, 0x00, 0x05,  # MOV R0, #5
        0x70, 0x00, 0x00, 0x04   # JMP START (address 4)
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
        0x00, 0x00, 0x00, 0x01,  # MOV R0, #1
        0x04, 0x00, 0x00, 0x05   # MOV R1, #5 (FIVE constant)
      ])
    end

    it 'raises an error for unknown instructions' do
      assembly_code = "UNKNOWN R0, #10"

      expect { assembler.assemble(assembly_code) }.to raise_error(RuntimeError, "Unknown instruction UNKNOWN")
    end

    it 'raises an error for undefined labels' do
      assembly_code = "JMP NONEXISTENT"

      expect { assembler.assemble(assembly_code) }.to raise_error(RuntimeError, "Undefined label or constant: NONEXISTENT")
    end

    it 'correctly assembles an ADD instruction' do
      assembly_code = "ADD R0, R1"
      machine_code = assembler.assemble(assembly_code)

      expect(machine_code[0..3]).to eq([
        0x11, 0x00, 0x00, 0x00  # ADD R0, R1 (0001 0001)
      ])
    end
  end

  describe '#first_pass' do
    it 'processes labels and directives correctly' do
      assembly_code = <<~ASM
        START:
        MOV R0, #10
        .org 100
        LABEL:
        ADD R0, R1
      ASM

      assembler.send(:first_pass, assembly_code)

      expect(assembler.instance_variable_get(:@labels)).to include('START' => 0, 'LABEL' => 100)
      expect(assembler.instance_variable_get(:@current_address)).to eq(104)
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
      expect(machine_code[0..7]).to eq([0x00, 0x00, 0x00, 0x0A, 0x11, 0x00, 0x00, 0x00])
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
      opcode = Svm::Assembler::ADD
      reg_x = 0  # R0
      reg_y = 1  # R1

      result = assembler.send(:combine_opcode_byte, opcode, reg_x, reg_y)

      expect(result).to eq(0x11)  # 0001 0001 in binary
    end

    it 'handles different register combinations for ADD' do
      opcode = Svm::Assembler::ADD
      # to ensure proper masking
      expect(assembler.send(:combine_opcode_byte, opcode, 0, 0)).to eq(0x10)  # ADD R0, R0
      expect(assembler.send(:combine_opcode_byte, opcode, 1, 2)).to eq(0x16)  # ADD R1, R2
      expect(assembler.send(:combine_opcode_byte, opcode, 2, 3)).to eq(0x1B)  # ADD R2, R3
      expect(assembler.send(:combine_opcode_byte, opcode, 3, 1)).to eq(0x1D)  # ADD R3, R1
    end
  end
end
