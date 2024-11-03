# Svm

Simple Virtual Machine (SVM)

The Simple Virtual Machine (SVM) is a lightweight register-based virtual machine written in Ruby, designed to execute a custom bytecode instruction set. It includes a memory array, a stack, and supports basic operations, conditional jumps, and I/O interrupts. Paired with the SVM assembler, you can write and compile assembly code into machine code for execution on this VM.

## Table of Contents

- [Installation](#installation)
- [Components](#components)
  - [Virtual Machine](#virtual-machine)
  - [Assembler](#assembler)
- [Instruction Set](#instruction-set)
- [Interrupts](#interrupts)
- [Example Usage](#example-usage)
- [License](#license)

## Installation

Clone the repository to your local machine and navigate to the project directory.

```bash
git clone <repo-url>
cd svm
```
Ensure you have Ruby installed, as this VM is implemented in pure Ruby.

## Components

### Virtual Machine

The Svm::VirtualMachine class is the core of the SVM. It simulates a CPU with general-purpose registers, memory, stack management, and an instruction set. Programs loaded into the VM can use these instructions to perform calculations, handle conditions, and manage functions.

- **Registers**: R0 to R3 for general use, PC (program counter), and SP (stack pointer).
- **Memory**: Array-based memory, 4096 bytes in size, divided between ROM (starting at address 0) and the main program (starting at address 2048).
- **Stack**: The VM includes a stack to handle function calls and intermediate data storage.

### Assembler

The Svm::Assembler class translates human-readable assembly code into bytecode compatible with the VM. It supports labels, directives (e.g., .org for memory organization), constants, and comments.

- **Labels**: Labels can be defined for jumps and function calls, making the code more readable.
- **Directives**:
  - `.org` sets the memory address where the code or data will reside.
  - `.data` reserves space in memory.
  - `.const` defines named constants.

## Instruction Format

Each instruction is 32 bits (4 bytes) long, with the following format:

1. First byte:
   - Bits 7-4: Opcode (4 bits)
   - Bits 3-2: First register (2 bits)
   - Bits 1-0: Second register (2 bits)
2. Second byte: Reserved for future expansion (currently unused)
3. Third and fourth bytes: Immediate value or memory address (16 bits)

## Instruction Set

| Opcode | Instruction | Description |
|--------|-------------|-------------|
| 0000 | INT | Trigger interrupt for I/O |
| 0001 | MOV | Load an immediate value into register |
| 0010 | ADD | Add values of two registers |
| 0011 | SUB | Subtract values of two registers |
| 0100 | MUL | Multiply values of two registers |
| 0101 | DIV | Divide values of two registers |
| 0110 | LOAD | Load a value from memory to register |
| 0111 | STORE | Store register value to memory |
| 1000 | JMP | Unconditional jump to address |
| 1001 | JEQ | Jump if equal |
| 1010 | JNE | Jump if not equal |
| 1011 | CALL | Call subroutine at address |
| 1100 | RET | Return from subroutine |
| 1101 | PUSH | Push register value to stack |
| 1110 | POP | Pop top of stack into register |
| 1111 | EXTENDED | Reserved for future instructions |

Note: For instructions with two register operands, the first register is always the destination, and the second register is the source. For single-operand instructions, the register is the destination.

## Interrupts

The SVM provides several interrupt operations for I/O and program control:

| Interrupt | Operation | Description |
|-----------|-----------|-------------|
| INT #0    | Halt      | Stops program execution |
| INT #1    | Print     | Prints value in R0 to stdout (prints "Output: <value>") |
| INT #2    | Read TTY  | Reads a character from TTY into R0 |
| INT #3    | Write TTY | Writes character in R0 to TTY |

Example interrupt usage:

```asm
; Basic output example
MOV R0, #65      ; Load ASCII 'A' into R0
INT #3           ; Write 'A' to TTY
INT #0           ; Halt program

; TTY echo example
START:
  INT #2         ; Read character from TTY into R0
  INT #3         ; Write character to TTY
  JMP START      ; Loop forever
```

Note: TTY operations (INT #2 and INT #3) require starting the VM's TTY connection using `vm.start_tty` before execution.

## Example Usage

Writing and Running a Program with the Assembler and Virtual Machine

```ruby
require_relative 'svm/virtual_machine'
require_relative 'svm/assembler'

# Sample assembly code
assembly_code = <<~ASM
  ; Define constants
  .const ROM_ADDRESS 0
  .const PROGRAM_START 2048
  .const RESULT_ADDRESS 129

  ; ROM code at memory 0
  .org ROM_ADDRESS
  JMP PROGRAM_START  ; Jump to main program

  ; Main program at memory 2048
  .org PROGRAM_START
START:
  MOV R0, #10      ; Load 10 into R0
  MOV R1, #14      ; Load 14 into R1
  ADD R0, R1       ; Add R1 to R0 (R0 now holds 24)
  STORE R0, RESULT_ADDRESS ; Store result in display memory at constant address

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

# Output result stored in display memory (at address defined by RESULT_ADDRESS)
display_result = vm.memory[129]  # We use 129 here as it's the value of RESULT_ADDRESS
puts "Result at #{129}: #{display_result}"  # Expecting output: 24
```

### Explanation of the Example

- **ROM and Program Setup**: The `.org` directive initializes the ROM at 0 and the main program at 2048.
- **Instructions**: The program loads 10 and 14, adds them, and stores the result in memory address 129 (RESULT).
- **Execution**: The program loops back to the START label to maintain continuity.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

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
