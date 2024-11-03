require 'spec_helper'
require 'svm/assembler'
require 'svm/virtual_machine'

RSpec.describe 'SVM Integration' do
  describe 'Assembly to Execution' do
    it 'correctly assembles and executes a simple program' do
      assembly_code = <<~ASM
        MOV R0, #10      ; Load 10 into R0
        MOV R1, #14      ; Load 14 into R1
        ADD R0, R1       ; Add R1 to R0
        INT #1           ; Print result
        INT #0           ; Halt
      ASM

      # Assemble the code
      assembler = Svm::Assembler.new
      machine_code = assembler.assemble(assembly_code)

      # Run in VM
      vm = Svm::VirtualMachine.new
      vm.load_program(machine_code,0)
      
      expect { vm.run }.to output("Output: 24\n").to_stdout
    end

    it 'handles forward and backward jumps' do
      assembly_code = <<~ASM
        MOV R0, #3       ; Initialize counter
        MOV R1, #1       ; Set decrement value
        START:           ; Loop start label
        INT #1          ; Print current value
        SUB R0, R1      ; Decrement counter using R1
        JNE R0, R2, START  ; Jump back if R0 != R2 (R2 defaults to 0)
        JMP END         ; Skip the error message
        MOV R0, #99     ; This should be skipped
        END:
        INT #0          ; Halt
      ASM

      # Assemble and run
      assembler = Svm::Assembler.new
      machine_code = assembler.assemble(assembly_code)
      vm = Svm::VirtualMachine.new
      vm.load_program(machine_code,0)
      vm.set_instruction_limit(50)  # Prevent infinite loops

      expect { vm.run }.to output("Output: 3\nOutput: 2\nOutput: 1\n").to_stdout
    end

    it 'handles labels correctly' do
      # Add assembler initialization
      assembler = Svm::Assembler.new
      vm = Svm::VirtualMachine.new
      
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
  end
end
