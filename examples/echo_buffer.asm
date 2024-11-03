; Initialize variables
.org 0
JMP START

; Constants
.const BUFFER_START 500    ; Start of our character buffer
.const BUFFER_SIZE 100     ; Maximum buffer size
.const ENTER_KEY 13       ; ASCII code for Enter
.const EXIT_STR 69        ; 'E'
.const EXIT_STR2 88       ; 'X'
.const EXIT_STR3 73       ; 'I'
.const EXIT_STR4 84       ; 'T'

; Variables
.org 400
BUFFER_POS: .data 1       ; Current position in buffer
EXIT_POS:   .data 1       ; Position in EXIT check

START:
  ; Initialize buffer position
  MOV R0, #0
  STORE R0, BUFFER_POS
  STORE R0, EXIT_POS

READ_LOOP:
  ; Read a character from TTY
  INT #2                  ; Read char into R0
  JEQ R0, R2, READ_LOOP  ; If no input (R0 = 0), keep waiting
  
  ; Check if it's Enter key
  MOV R1, #ENTER_KEY
  JEQ R0, R1, PROCESS_BUFFER

  ; Store character in buffer
  LOAD R1, BUFFER_POS    ; Get current buffer position
  MOV R2, #BUFFER_START
  ADD R2, R1             ; Calculate buffer address
  STORE R0, R2           ; Store character
  
  ; Increment buffer position
  ADD R1, #1
  STORE R1, BUFFER_POS
  
  ; Check for "EXIT" sequence
  CALL CHECK_EXIT
  JMP READ_LOOP

CHECK_EXIT:
  ; Get current EXIT check position
  LOAD R1, EXIT_POS
  
  ; Compare with expected character based on position
  MOV R2, #0
  JNE R1, R2, CHECK_E    ; If not first position, check others
  MOV R2, #EXIT_STR
  JNE R0, R2, RESET_EXIT ; If not 'E', reset
  JMP INCREMENT_EXIT

CHECK_E:
  MOV R2, #1
  JNE R1, R2, CHECK_X
  MOV R2, #EXIT_STR2
  JNE R0, R2, RESET_EXIT
  JMP INCREMENT_EXIT

CHECK_X:
  MOV R2, #2
  JNE R1, R2, CHECK_I
  MOV R2, #EXIT_STR3
  JNE R0, R2, RESET_EXIT
  JMP INCREMENT_EXIT

CHECK_I:
  MOV R2, #3
  JNE R1, R2, RESET_EXIT
  MOV R2, #EXIT_STR4
  JNE R0, R2, RESET_EXIT
  JMP INCREMENT_EXIT

INCREMENT_EXIT:
  ADD R1, #1
  STORE R1, EXIT_POS
  RET

RESET_EXIT:
  MOV R1, #0
  STORE R1, EXIT_POS
  RET

PROCESS_BUFFER:
  ; Check if EXIT was typed
  LOAD R0, EXIT_POS
  MOV R1, #4
  JEQ R0, R1, HALT_PROGRAM

  ; Output all characters in buffer
  MOV R0, #0             ; Initialize counter
OUTPUT_LOOP:
  LOAD R1, BUFFER_POS    ; Get buffer size
  JEQ R0, R1, RESET_BUFFER ; If counter equals buffer size, done
  
  MOV R2, #BUFFER_START
  ADD R2, R0             ; Calculate buffer address
  LOAD R3, R2            ; Load character
  MOV R0, R3             ; Move to R0 for output
  INT #3                 ; Output character
  
  LOAD R0, R2            ; Restore counter
  SUB R0, #BUFFER_START  ; Convert back to counter
  ADD R0, #1             ; Increment counter
  JMP OUTPUT_LOOP

RESET_BUFFER:
  MOV R0, #0
  STORE R0, BUFFER_POS   ; Reset buffer position
  STORE R0, EXIT_POS     ; Reset EXIT check
  JMP READ_LOOP

HALT_PROGRAM:
  INT #0                 ; Halt
