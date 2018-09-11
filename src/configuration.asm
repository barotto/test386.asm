; ==============================================================================
;   CONFIGURATION
;
;   If your system needs a specific LPT or COM initialization procedure put it
;   inside the print_init.asm file.
;
; ==============================================================================

; The diagnostic port used to emit the current test procedure number.
; Possible values: the 16-bit value of the diagnostic port of your system.
POST_PORT equ 0x190

; The parallel port to use to print ASCII computational results.
; Possible values: 0=disabled, 1=LPT1 (3BCh), 2=LPT2 (378h), 3=LPT3 (278h)
LPT_PORT equ 1

; The serial port to use to print ASCII computational results.
; Possible values: 0=disabled, 1=COM1 (3F8h-3FDh), 2=COM2 (2F8h-2FDh)
COM_PORT equ 0

; Additional port for direct ASCII output.
; Possible values: any 16-bit value, 0=disabled.
OUT_PORT equ 0

; Enable POST E0 test for undefined behaviours and bugs. You also need to
; specify the CPU model your emulator implements (see CPU_FAMILY).
; Possible values: 1=enable POST E0, 0=skip the tests
TEST_UNDEF equ 0

; The CPU family used when POST E0 is enabled (otherwise unused).
; Possible values: 3=80386
CPU_FAMILY equ 3

; Intel's reference manuals for 80386 and 80486 CPUs have different behaviour
; described for combined Page Directory and Page Table protection, compared to
; what is described in manuals for Pentium and later processors. I'm not sure
; if the manuals are wrong or Intel changed the protection mechanism.
; This Equ lets you define what version of the manual is your emulator
; following. See tests/paging_p.asm for more info.
; Possible values: 0=skip tests, 3=386 and 486 rules, 5=Pentium and later rules
TEST_PAGING equ 0

; The Bochs x86 PC emulator behaves differently than real hardware in the ARPL
; operation and fails on that specific test. Enable this Equ if you want to use
; Bochs.
; Possible values: 1=enable Bochs, 0=disable Bochs
BOCHS equ 0

; The IBM PS/1 needs special commands to initialize LPT and COM ports.
; Possible values: 1=enable PS/1 initialization, 0=your machine is not a PS/1
IBM_PS1 equ 0

; Enable some additional text output on the output ports (useful for test386.asm
; debugging).
DEBUG equ 0


; == END OF CONFIGURATION ======================================================
