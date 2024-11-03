require 'spec_helper'
require 'svm/virtual_machine'
require 'socket'
require 'fileutils'

RSpec.describe 'TTY Integration' do
  let(:vm) { Svm::VirtualMachine.new }
  let(:test_port) { 4567 }

  before(:each) do
    # Ensure any previous VMs are cleaned up
    vm.stop_tty if vm.instance_variable_get(:@tty)
    sleep 0.1
  end

  after(:each) do
    vm.stop_tty if vm.instance_variable_get(:@tty)
    sleep 0.1
  end

  describe 'VM with TTY connection' do
    it 'handles basic I/O through TTY' do
      # Modified echo program to wait for input
      assembly_code = <<~ASM
MOV R3, #5        ; Set counter for max iterations
START:
  INT #2          ; Read character from TTY into R0
  JEQ R0, R2, START  ; If no input (R0 = 0), keep waiting
  STORE R0, 500   ; Store the character in memory
  MOV R1, R0      ; Save character to R1
  INT #3          ; Write R0 to TTY
  SUB R3, #1      ; Decrement counter
  JNE R3, R2, START  ; Loop if counter not zero
  INT #0          ; Halt
ASM

      assembler = Svm::Assembler.new
      machine_code = assembler.assemble(assembly_code)
      vm.load_program(machine_code,0)
      
      # Set instruction limit to prevent infinite loops
      vm.set_instruction_limit(50000)
      
      # Start VM TTY first
      vm.start_tty
      sleep 0.2 # Allow server to start

      # Connect test client before starting VM
      client = TCPSocket.new('localhost', test_port)
      sleep 0.1

      # Now start VM in separate thread
      vm_thread = Thread.new { vm.run }
      sleep 0.2

      # Send test data
      client.write('A')
      sleep 0.2  # Give more time for processing

      # Read response
      response = ''
      3.times do |i|
        begin
          data = client.read_nonblock(1024)
          response += data
        rescue IO::WaitReadable
          sleep 0.2
        rescue EOFError
          break
        end
      end

      # Verify response contains our echo'd character
      expect(response).to include('A')

      # Verify the character was stored in memory
      expect(vm.instance_variable_get(:@memory)[500]).to eq('A'.ord)  # 65 for 'A'

      # Clean up
      vm.instance_variable_set(:@running, false)
      vm_thread.join(1)
      client.close
      vm.stop_tty
    end

    it 'handles multiple TTY clients' do
      vm.start_tty
      sleep 0.1

      clients = 3.times.map { TCPSocket.new('localhost', test_port) }
      
      # Send data from each client
      clients.each_with_index do |client, i|
        client.write("#{i}")
        sleep 0.1
      end

      # Verify each client received initialization
      clients.each do |client|
        init_data = client.read_nonblock(1024) rescue nil
        expect(init_data).not_to be_nil
      end

      clients.each(&:close)
      vm.stop_tty
    end
  end
end 