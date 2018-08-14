; ==============================================================================
;   CONFIGURATION
;
;   If your system needs a specific LPT or COM initialization procedure put it
;   inside the print_init.asm file.
;
; ==============================================================================

POST_PORT  equ 0x190 ; hex, the diagnostic port used to emit the current test procedure
LPT_PORT   equ 1     ; integer, parallel port to use, 0=LPT disabled, 1=3BCh, 2=378h, 3=278h
COM_PORT   equ 0     ; integer, serial port to use, 0=COM disabled, 1=3F8h-3FDh, 2=2F8h-2FDh
OUT_PORT   equ 0x0   ; hex, additional port for direct ASCII output, 0=disabled
TEST_UNDEF equ 0     ; boolean, enable undefined behaviours tests
CPU_FAMILY equ 3     ; integer, used to test undefined behaviours, 3=80386
IBM_PS1    equ 0     ; boolean, enable specific code for the IBM PS/1 2011 and 2121 models
BOCHS      equ 0     ; boolean, enable compatibility with the Bochs x86 PC emulator

; == END OF CONFIGURATION ======================================================
