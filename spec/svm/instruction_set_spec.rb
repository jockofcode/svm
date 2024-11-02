require 'spec_helper'
require 'svm/instruction_set'

RSpec.describe Svm::InstructionSet do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Svm::InstructionSet
    end
  end

  let(:instance) { test_class.new }

  describe 'opcodes' do
    it 'defines all expected opcodes as constants' do
      expected_opcodes = %w[MOV ADD SUB MUL DIV LOAD STORE JMP JEQ JNE CALL RET PUSH POP INT EXTENDED]
      
      expected_opcodes.each_with_index do |opcode, index|
        expect(Svm::InstructionSet.const_get(opcode)).to eq(index)
      end
    end

    it 'assigns sequential values starting from 0' do
      expect(Svm::InstructionSet::MOV).to eq(0)
      expect(Svm::InstructionSet::ADD).to eq(1)
      expect(Svm::InstructionSet::SUB).to eq(2)
      expect(Svm::InstructionSet::EXTENDED).to eq(15)
    end
  end

  describe '#combine_opcode_byte' do
    it 'correctly combines opcode and registers into a byte' do
      expect(instance.combine_opcode_byte(0, 0, 0)).to eq(0b00000000)  # MOV R0, R0
      expect(instance.combine_opcode_byte(1, 1, 2)).to eq(0b00010110)  # ADD R1, R2
      expect(instance.combine_opcode_byte(15, 3, 3)).to eq(0b11111111) # EXTENDED R3, R3
    end

    it 'masks out excess bits' do
      # Test with values that exceed their bit widths
      expect(instance.combine_opcode_byte(0b11111, 0b1111, 0b1111)).to eq(0b11111111)  # 255
      expect(instance.combine_opcode_byte(0, 0b1111, 0b1111)).to eq(0b00001111)        # 15
    end
  end

  describe '#split_opcode_byte' do
    it 'correctly splits a byte into opcode and registers' do
      # Test MOV R0, R0 (0000 00 00)
      opcode, reg_x, reg_y = instance.split_opcode_byte(0b00000000)
      expect(opcode).to eq(0)
      expect(reg_x).to eq(0)
      expect(reg_y).to eq(0)

      # Test ADD R1, R2 (0001 01 10)
      opcode, reg_x, reg_y = instance.split_opcode_byte(0b00010110)
      expect(opcode).to eq(1)
      expect(reg_x).to eq(1)
      expect(reg_y).to eq(2)

      # Test EXTENDED R3, R3 (1111 11 11)
      opcode, reg_x, reg_y = instance.split_opcode_byte(0b11111111)
      expect(opcode).to eq(15)
      expect(reg_x).to eq(3)
      expect(reg_y).to eq(3)
    end

    it 'correctly handles all possible register combinations' do
      # Test all register combinations for ADD instruction
      reg_combinations = [
        [0, 0], [0, 1], [0, 2], [0, 3],
        [1, 0], [1, 1], [1, 2], [1, 3],
        [2, 0], [2, 1], [2, 2], [2, 3],
        [3, 0], [3, 1], [3, 2], [3, 3]
      ]

      reg_combinations.each do |reg_x, reg_y|
        byte = instance.combine_opcode_byte(1, reg_x, reg_y)
        opcode, rx, ry = instance.split_opcode_byte(byte)
        expect(opcode).to eq(1)
        expect(rx).to eq(reg_x)
        expect(ry).to eq(reg_y)
      end
    end
  end

  describe 'roundtrip conversion' do
    it 'preserves values when combining and splitting' do
      test_cases = [
        [0, 0, 0],   # MOV R0, R0
        [1, 1, 2],   # ADD R1, R2
        [15, 3, 3],  # EXTENDED R3, R3
        [7, 2, 1],   # JMP R2, R1
        [3, 1, 3]    # MUL R1, R3
      ]

      test_cases.each do |opcode, reg_x, reg_y|
        byte = instance.combine_opcode_byte(opcode, reg_x, reg_y)
        split_opcode, split_reg_x, split_reg_y = instance.split_opcode_byte(byte)
        
        expect(split_opcode).to eq(opcode)
        expect(split_reg_x).to eq(reg_x)
        expect(split_reg_y).to eq(reg_y)
      end
    end
  end

  describe '#mask_opcode' do
    it 'masks to 4 bits' do
      expect(instance.mask_opcode(0b11111)).to eq(0b1111)
      expect(instance.mask_opcode(0b10000)).to eq(0b0000)
    end
  end

  describe '#mask_register' do
    it 'masks to 2 bits' do
      expect(instance.mask_register(0b1111)).to eq(0b11)
      expect(instance.mask_register(0b1100)).to eq(0b00)
    end
  end

  describe '#shift_opcode' do
    it 'shifts 4 bits left' do
      expect(instance.shift_opcode(0b1111)).to eq(0b11110000)
      expect(instance.shift_opcode(0b0001)).to eq(0b00010000)
    end
  end

  describe '#shift_reg_x' do
    it 'shifts 2 bits left' do
      expect(instance.shift_reg_x(0b11)).to eq(0b1100)
      expect(instance.shift_reg_x(0b01)).to eq(0b0100)
    end
  end
end 