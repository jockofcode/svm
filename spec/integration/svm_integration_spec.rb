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
      vm.load_program(machine_code)
      
      expect { vm.run }.to output("Output: 24\n").to_stdout
    end
  end
end
