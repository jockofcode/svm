require 'spec_helper'
require 'svm/virtual_machine'

RSpec.describe Svm::VirtualMachine do
  let(:vm) { Svm::VirtualMachine.new }

  describe '#initialize' do
    it 'initializes with correct memory size' do
      expect(vm.instance_variable_get(:@memory).size).to eq(Svm::VirtualMachine::MEMORY_SIZE)
    end

    it 'initializes with correct number of registers' do
      expect(vm.instance_variable_get(:@registers).size).to eq(4)
    end

    it 'initializes with correct program counter' do
      expect(vm.instance_variable_get(:@PC)).to eq(Svm::VirtualMachine::PROGRAM_START)
    end

    it 'initializes with correct stack pointer' do
      expect(vm.instance_variable_get(:@SP)).to eq(Svm::VirtualMachine::MEMORY_SIZE - 1)
    end
  end

  describe '#load_program' do
    it 'loads a program into memory' do
      program = [0x00, 0x01, 0x02, 0x03]
      vm.load_program(program)
      expect(vm.instance_variable_get(:@memory)[Svm::VirtualMachine::PROGRAM_START, 4]).to eq(program)
    end

    it 'loads a program at a specified address' do
      program = [0x00, 0x01, 0x02, 0x03]
      custom_address = 3000
      vm.load_program(program, custom_address)
      expect(vm.instance_variable_get(:@memory)[custom_address, 4]).to eq(program)
    end
  end

  describe '#run' do
    it 'executes a simple program' do
      program = [
        0x00, 0x00, 0x00, 0x0A,  # MOV R0, #10
        0x04, 0x00, 0x00, 0x0E,  # MOV R1, #14
        0x11, 0x00, 0x00, 0x00,  # ADD R0, R1
        0x60, 0x00, 0x00, 0x80,  # STORE R0, 129
        0xE0, 0x00, 0x00, 0x00   # INT #0 (halt)
      ]
      vm.load_program(program)
      vm.run()
      
      expect(vm.instance_variable_get(:@memory)[Svm::VirtualMachine::DISPLAY_START]).to eq(24)
    end

    it 'raises an error on infinite MOV R0, #0 loop' do
      program = [
        vm.combine_opcode_byte(Svm::VirtualMachine::MOV,0,0), 0x00, 0x00, 0x00,  # MOV R0, #0
        vm.combine_opcode_byte(Svm::VirtualMachine::MOV,0,0), 0x00, 0x00, 0x00   # MOV R0, #0
      ]
      vm.load_program(program)
      expect { 
        vm.run 
      }.to raise_error(RuntimeError, "Running blank code detected: MOV R0, #0 executed 2 times consecutively")
    end
  end

  describe 'stack operations' do
    it 'pushes and pops values correctly' do
      vm.send(:push_word, 42)
      expect(vm.send(:pop_word)).to eq(42)
    end

    it 'handles multiple push and pop operations' do
      vm.send(:push_word, 10)
      vm.send(:push_word, 20)
      vm.send(:push_word, 30)
      expect(vm.send(:pop_word)).to eq(30)
      expect(vm.send(:pop_word)).to eq(20)
      expect(vm.send(:pop_word)).to eq(10)
    end
  end

  describe '#handle_interrupt' do
    it 'handles output interrupt' do
      vm.instance_variable_set(:@registers, [42, 0, 0, 0])
      expect { vm.send(:handle_interrupt, 1) }.to output("Output: 42\n").to_stdout
    end

    it 'raises an error for unknown interrupt' do
      expect { vm.send(:handle_interrupt, 99) }.to raise_error(RuntimeError, "Unknown interrupt: 99")
    end
  end

  describe 'instruction execution' do
    before do
      vm.instance_variable_set(:@running, false)  # Prevent infinite loop
      vm.instance_variable_set(:@PC, Svm::VirtualMachine::PROGRAM_START)  # Reset PC
    end

    it 'executes MOV instruction' do
      vm.load_program([vm.combine_opcode_byte(0,0,0), 0x00, 0x00, 0x0A])  # MOV R0, #10
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(10)
    end

    it 'executes ADD instruction' do
      vm.instance_variable_set(:@registers, [5, 3, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::ADD,0,1), 0x00, 0x00, 0x00])  # ADD R0, R1
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(8)
    end

    it 'executes JMP instruction' do
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::JMP,0,0), 0x00, 0x03, 0x01])  # JMP #769
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(769)
    end

    it 'executes STORE instruction' do
      vm.instance_variable_set(:@registers, [42, 0, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::STORE,0,0), 0x00, 0x00, 0x81])  # STORE R0, 129
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@memory)[129]).to eq(42)   # Store full 16-bit value in single location
    end

    it 'executes SUB instruction' do
      vm.instance_variable_set(:@registers, [10, 3, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::SUB,0,1), 0x00, 0x00, 0x00])  # SUB R0, R1
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(7)
    end

    it 'executes MUL instruction' do
      vm.instance_variable_set(:@registers, [5, 3, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::MUL,0,1), 0x00, 0x00, 0x00])  # MUL R0, R1
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(15)
    end

    it 'executes DIV instruction' do
      vm.instance_variable_set(:@registers, [10, 2, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::DIV,0,1), 0x00, 0x00, 0x00])  # DIV R0, R1
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(5)
    end

    it 'executes LOAD instruction' do
      vm.instance_variable_set(:@memory, Array.new(4096, 0))
      vm.instance_variable_get(:@memory)[100] = 42  # Store value directly
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::LOAD,0,0), 0x00, 0x00, 0x64])  # LOAD R0, 100
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(42)
    end

    it 'executes JEQ instruction when equal' do
      vm.instance_variable_set(:@registers, [5, 5, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::JEQ,0,1),  0x00, 0x04, 0x06])  # JEQ R0, R1, 1030
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(1030)
    end

    it 'executes JEQ instruction when not equal' do
      vm.instance_variable_set(:@registers, [5, 6, 0, 0])
      expect(vm.instance_variable_get(:@PC)).to eq(Svm::VirtualMachine::PROGRAM_START)
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::JEQ,0,1),  0x00, 0x04, 0x06])  # JEQ R0, R1, 1030
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(Svm::VirtualMachine::PROGRAM_START + 4)
    end

    it 'executes JNE instruction when not equal' do
      vm.instance_variable_set(:@registers, [5, 6, 0, 0])
      expect(vm.instance_variable_get(:@PC)).to eq(Svm::VirtualMachine::PROGRAM_START)
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::JNE,0,1),  0x00, 0x04, 0x05])  # JNE R0, R1, 1029
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(1029)
    end

    it 'executes JNE instruction when equal' do
      vm.instance_variable_set(:@registers, [5, 5, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::JNE,0,1),  0x00, 0x04, 0x07])  # JNE R0, R1, 1031
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(Svm::VirtualMachine::PROGRAM_START + 4)
    end

    it 'executes CALL instruction' do
      initial_pc = vm.instance_variable_get(:@PC)
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::CALL,0,0),  0x00, 0x04, 0x06])  # CALL 1030
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(1030)
      expect(vm.send(:pop_word)).to eq(initial_pc + 4)
    end

    it 'executes RET instruction' do
      vm.send(:push_word, 3049)
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::RET,0,0), 0x00, 0x00, 0x00])  # RET
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@PC)).to eq(3049)
    end

    it 'executes PUSH instruction' do
      vm.instance_variable_set(:@registers, [42, 0, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::PUSH,0,0), 0x00, 0x00, 0x00])  # PUSH R0
      vm.send(:execute_instruction)
      expect(vm.send(:pop_word)).to eq(42)
    end

    it 'executes POP instruction' do
      vm.send(:push_word, 42)
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::POP,0,0), 0x00, 0x00, 0x00])  # POP R0
      vm.send(:execute_instruction)
      expect(vm.instance_variable_get(:@registers)[0]).to eq(42)
    end

    it 'executes INT instruction' do
      vm.instance_variable_set(:@registers, [42, 0, 0, 0])
      vm.load_program([vm.combine_opcode_byte(Svm::VirtualMachine::INT,0,0), 0x00, 0x00, 0x01])  # INT 1
      expect { vm.send(:execute_instruction) }.to output("Output: 42\n").to_stdout
    end
  end

  describe '#split_opcode_byte' do
    it 'correctly splits an opcode byte' do
      vm = Svm::VirtualMachine.new
      byte = 0b11100101  # opcode: 14, reg_x: 1, reg_y: 1
      opcode, reg_x, reg_y = vm.send(:split_opcode_byte, byte)
      expect(opcode).to eq(14)
      expect(reg_x).to eq(1)
      expect(reg_y).to eq(1)
    end
  end

  describe '#combine_opcode_byte' do
    it 'correctly combines opcode and registers into a byte' do
      vm = Svm::VirtualMachine.new
      byte = vm.send(:combine_opcode_byte, 14, 1, 1)
      expect(byte).to eq(0b11100101)
    end

    it 'handles edge cases correctly' do
      assembler = Svm::Assembler.new
      expect(assembler.send(:combine_opcode_byte, 15, 3, 3)).to eq(0b11111111)
      expect(assembler.send(:combine_opcode_byte, 0, 0, 0)).to eq(0b00000000)
    end
  end

  describe '16-bit register operations' do
    it 'handles 16-bit values in registers' do
      vm = Svm::VirtualMachine.new
      program = [
        0x00, 0x00, 0xFF, 0xFF,  # MOV R0, #65535 (max 16-bit value)
        0x04, 0x00, 0x00, 0x01,  # MOV R1, #1
        0x11, 0x00, 0x00, 0x00,  # ADD R0, R1 (0001 0001)
        0xE0, 0x00, 0x00, 0x00   # INT #0 (halt)
      ]
      
      vm.load_program(program)
      vm.run
      
      expect(vm.instance_variable_get(:@registers)[0]).to eq(0)  # Should wrap around to 0
    end

    it 'properly stores and loads 16-bit values' do
      vm = Svm::VirtualMachine.new
      program = [
        0x00, 0x00, 0x12, 0x34,  # MOV R0, #0x1234
        0x60, 0x00, 0x00, 0x80,  # STORE R0, 128
        0x54, 0x00, 0x00, 0x80,  # LOAD R1, 128  (0101 0100 in binary)
        0xE0, 0x00, 0x00, 0x00   # INT #0 (halt)
      ]
      
      vm.load_program(program)
      vm.run
      
      expect(vm.instance_variable_get(:@registers)[1]).to eq(0x1234)
    end
  end
end
