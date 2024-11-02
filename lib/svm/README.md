# Svm
Simple Virtual Machine (SVM)
The Simple Virtual Machine (SVM) is a lightweight register-based virtual machine written in Ruby, designed to execute a custom bytecode instruction set. It includes a memory array, a stack, and supports basic operations, conditional jumps, and I/O interrupts. Paired with the SVM assembler, you can write and compile assembly code into machine code for execution on this VM.

Table of Contents
Installation
Components
Virtual Machine
Assembler
Instruction Set
Example Usage
License
Installation
Clone the repository to your local machine and navigate to the project directory.

```bash
git clone <repo-url>
cd svm
```
Ensure you have Ruby installed, as this VM is implemented in pure Ruby.

Components
Virtual Machine
The Svm::VirtualMachine class is the core of the SVM. It simulates a CPU with general-purpose registers, memory, stack management, and an instruction set. Programs loaded into the VM can use these instructions to perform calculations, handle conditions, and manage functions.

Registers: R0 to R3 for general use, PC (program counter), and SP (stack pointer).
Memory: Array-based memory, 4096 bytes in size, divided between ROM (starting at address 0) and the main program (starting at address 2049).
Stack: The VM includes a stack to handle function calls and intermediate data storage.
Assembler
The Svm::Assembler class translates human-readable assembly code into bytecode compatible with the VM. It supports labels, directives (e.g., .org for memory organization), constants, and comments.

Labels: Labels can be defined for jumps and function calls, making the code more readable.
Directives:
.org sets the memory address where the code or data will reside.
.data reserves space in memory.
.const defines named constants.
Instruction Set
Opcode	Instruction	Description
0	INT	Trigger interrupt for I/O
1	MOV	Move value between registers or load an immediate value
2	ADD	Add values of two registers
3	SUB	Subtract values of two registers
4	MUL	Multiply values of two registers
5	DIV	Divide values of two registers
6	LOAD	Load a value from memory to register
7	STORE	Store register value to memory
8	JMP	Unconditional jump to address
9	JEQ	Jump if equal
10	JNE	Jump if not equal
11	CALL	Call subroutine at address
12	RET	Return from subroutine
13	PUSH	Push register value to stack
14	POP	Pop top of stack into register
15	EXTENDED	Reserved for future instructions
Example Usage
Writing and Running a Program with the Assembler and Virtual Machine
```ruby
require_relative 'svm/virtual_machine'
require_relative 'svm/assembler'

# Sample assembly code
assembly_code = <<~ASM
  ; ROM code at memory 0
  .org 0
  JMP START        ; Jump to main program

  ; Main program at memory 2049
  .org 2049
START:
  MOV R0, #10      ; Load 10 into R0
  MOV R1, #14      ; Load 14 into R1
  ADD R0, R1       ; Add R1 to R0 (R0 now holds 24)
  STORE R0, RESULT ; Store result in display memory at 129

RESULT:
  .data 1          ; Reserve 1 byte for the result

  JMP START        ; Loop indefinitely
ASM

# Initialize assembler and generate machine code
assembler = Svm::Assembler.new
machine_code = assembler.assemble(assembly_code)

# Initialize virtual machine and load machine code
vm = Svm::VirtualMachine.new
vm.load_program(machine_code)

# Run the virtual machine
vm.run

# Output result stored in display memory (at address 129)
display_result = vm.memory[129]
puts "Result at 129: #{display_result}"  # Expecting output: 24
```
### Explanation of the Example
ROM and Program Setup: The .org directive initializes the ROM at 0 and the main program at 2049.
Instructions: The program loads 10 and 14, adds them, and stores the result in memory address 129 (RESULT).
Execution: The program loops back to the START label to maintain continuity.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/svm. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/svm/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Svm project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/svm/blob/main/CODE_OF_CONDUCT.md).
