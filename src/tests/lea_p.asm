; Testing of 32-bit addressing using the LEA instruction.
; Every possible combination of ModRM and SIB is tested (6312 valid for LEA).
;
; I'm using a different approach than the arith-logic tests at POST EEh.
; Instead of manually writing every possible instruction to execute and letting
; the CPU write the results to the output port, I'll use a self modifying test
; routine. The computed EA will be immediately compared with the expected result.
;
; Is this really necessary? No.
; Was it fun to code at least? Somewhat.
; Would I do it again? Probably not.
; What is a reasonable alternative? Create a binary table with every possible
; valid combination of the LEA instruction followed by RET; this is a fairly
; easy, 1-time job that is less prone to bugs.
; For every entry in the table:
; 1. initialize every register with known values
; 2. call the LEA+RET code at the current table offset
; 3. print the value of every register to the output port
; At the end, manually compare the output with a reference.
; Don't depend on NASM to assemble the LEA instructions, it tends to use
; optimizations.


;
; This is the routine that will be updated, to be copied in system memory.
; A couple of loops in the driver will iterate through every combination of the
; ModRM and SIB bytes used in a LEA instruction. A CMP instruction will then be
; executed to do a comparison between the computed EA and the expected correct
; value. A final MOV r/m32,r32 will move the computed EA in ES:[0] for later use
; (debug).
;
addr32TestCode:
	pushad ; save current regs values
	mov [es:4], esp ; save ESP

	; fill in the values to be used for effective address computation
	mov eax, 0x001
	mov ebx, 0x002
	mov ecx, 0x004
	mov edx, 0x008
	mov esp, 0x020
	mov ebp, 0x040
	mov esi, 0x080
	mov edi, 0x100

	%define disp8value  0x80
	%define disp32value 0x80000000

	db 0x8D ; LEA, lenght=2-7
	.leaModRM:   db 0x00 ; ModRM byte
	.leaSIBDisp: db 0x90 ; SIB byte or disp8/disp32 or NOP
	.leaDisp:    db 0x90,0x90,0x90 ; disp8 or disp32, if SIB is used, else NOPs
	.leaLastByte:db 0x90 ; the last possible byte, if SIB and disp32 are used, else NOP

	;jmp .skipCMP ; DEBUG

	db 0x81 ; CMP (81/7), lenght=6
	.cmpModRM: db 0 ; ModRM byte, the register to compare is derived from LEA's ModRM
	.cmpImm32: dd 0 ; 32-bit immediate value for comparison

.skipCMP:
	db 0x26 ; ES prefix
	db 0x89 ; MOV, lenght=5
	.movModRM: db 0 ; ModRM byte, the register to move is the same as LEA's ModRM
	dd 0 ; disp32

	mov esp, [es:4] ; restore ESP
	je .exit
	call C_SEG_PROT32:error

.exit
	popad ; restore regs
	retf
.end:

%assign leaModRMOff    addr32TestCode.leaModRM   - addr32TestCode
%assign leaSIBDispOff  addr32TestCode.leaSIBDisp - addr32TestCode
%assign leaDispOff     addr32TestCode.leaDisp    - addr32TestCode
%assign leaLastByteOff addr32TestCode.leaLastByte- addr32TestCode
%assign cmpModRMOff    addr32TestCode.cmpModRM   - addr32TestCode
%assign cmpImm32Off    addr32TestCode.cmpImm32   - addr32TestCode
%assign movModRMOff    addr32TestCode.movModRM   - addr32TestCode


;
; This is the testing driver. Two loops, 1 for ModRM and 1 for the current SIB
; (when present), will generate the missing parts of the LEA and CMP
; instructions of the testing routine.
;
; x86 addressing is a bit convoluted and has some special cases:
; - if Mod=00b and R/M=100b then SIB is present
; - if Mod=00b and R/M=100b and Base=101b then SIB+disp32 are present
; - if Mod=00b and R/M=101b then disp32 is present
; - if Mod=01b then disp8 is present
; - if Mod=01b and R/M=100b then SIB+disp8 are present
; - if Mod=10b then disp32 is present
; - if Mod=10b and R/M=100b then SIB+disp32 are present
;
; 7      6 5         3 2          0
; ╔═══╤═══╤═══╤═══╤═══╤═══╤═══╤═══╗
; ║  Mod  │    Reg    │    R/M    ║ ModRM
; ╚═══╧═══╧═══╧═══╧═══╧═══╧═══╧═══╝
;
; 7      6 5         3 2          0
; ╔═══╤═══╤═══╤═══╤═══╤═══╤═══╤═══╗
; ║ Scale │   Index   │   Base    ║ SIB
; ╚═══╧═══╧═══╧═══╧═══╧═══╧═══╧═══╝
;
testAddressing32:
	; dynamic code segment base = D1_SEG_PROT base
	updLDTDescBase DC_SEG_PROT32,TEST_BASE1

	; copy the test routine in RAM
	mov ecx, addr32TestCode.end - addr32TestCode
	mov ax, C_SEG_PROT32 ; source = C_SEG_PROT32:addr32TestCode
	mov ds, ax
	mov esi, addr32TestCode
	mov ax, D1_SEG_PROT  ; dest = D1_SEG_PROT:0
	mov es, ax
	mov edi, 0
	cld
	rep movsb

	mov ax, D1_SEG_PROT
	mov ds, ax ; DS = writeable code segment
	mov ax, D2_SEG_PROT
	mov es, ax ; ES = scratch pad

	; AL = LEA modrm byte
	; AH = LEA SIB byte
	; EAX16 = LEA SIB present?
	; BL = CMP modrm byte
	; BH = LEA last byte value
	; ECX15-0 = ModRM loop counter
	; ECX31-16 = SIB loop counter
	; DL = index in the CMP values table
	; DH = ModRM of the MOV
	; ESI = LEA 8/32-bit displacement
	; EDI = LEA displacement value offset

	xor eax, eax
	mov ecx, 0x010000C0 ; ModRM values C0-FF are not valid for LEA

.calcModRMValues:
	call addr32CalcLEAValues
	call addr32CalcCMPValues
	call addr32CalcMOVValues
	call addr32CopyValues
	; call addr32PrintStatus ; enable for DEBUG

	%if TEST_UNDEF = 0
	; Index = 4 and SS != 0 is undefined behaviour.
	; Since we are not testing UB we need to skip this case.
	; i386: in the absence of an index register the scale factor is applied to the base register.
	test eax, 0x10000 ; is SIB used?
	jz .runTest       ; no, proceed with the test
	mov bp, ax
	shr bp, 8         ; BP = AH = SIB 
	and bp, 00111000b ; select Index
	cmp bp, 00100000b ; is Index eq 4?
	jne .runTest      ; no, proceed with the test
	mov bp, ax
	shr bp, 8
	and bp, 11000000b ; select SS
	cmp bp, 0         ; is SS eq 0?
	jne .endTest      ; no, skip the test (UB)
	%endif
.runTest:
	call DC_SEG_PROT32:0
	; call addr32PrintResult ; enable for DEBUG
.endTest:
	test eax, 0x10000 ; is SIB used?
	jnz .nextSIB
.nextModRM:
	inc al ; next LEA ModRM value
	jmp .loop
.nextSIB:
	inc ah ; next LEA SIB value
	a16 loop .calcModRMValues
	; if we end here then the SIB loop is over
	and  eax, 0x0ffff  ; disable SIB byte flag
	mov  cx, 0x100     ; reset SIB loop counter
	rol  ecx, 16       ; switch SIB loop cnt with ModRM loop cnt
	jmp .nextModRM
.loop:
	a16 loop .calcModRMValues
	; outer ModRM loop finished
	ret


addr32CalcLEAValues:
	; handle the SIB byte
	mov ebp, eax
	and ebp, 111b ; LEA R/M value
	cmp ebp, 100b ; SIB encoding?
	jne .noSIB
.SIB:
	mov  edi, leaDispOff    ; displacement, if present, is after SIB
	test eax, 0x10000       ; was prev iteration with SIB?
	jnz .disp
	or   eax, 0x10000       ; enable SIB byte flag
	rol  ecx, 16            ; switch ModRM loop with SIB loop
	jmp .disp
.noSIB:
	mov  edi, leaSIBDispOff ; displacement, if present, is after opcode

	; handle disp8/disp32
.disp:
	mov  esi, 0x90909090    ; init with NOPs
	mov  ebp, eax
	shr  ebp, 6
	and  ebp, 11b     ; Mod
	cmp  ebp, 01b     ; Mod=01, disp8
	je  .disp8
	cmp  ebp, 10b     ; Mod=10, disp32
	je  .disp32
	cmp  ebp, 11b     ; Mod=11 no displacement
	je  .lastByte
	mov  ebp, eax
	and  ebp, 111b    ; R/M
	cmp  ebp, 101b    ; Mod=00 and R/M=101, disp32
	je  .disp32
	cmp  ebp, 100b    ; Mod=00 and R/M=100, is SIB Base=101?
	jne .lastByte
	mov  ebp, eax
	shr  ebp, 8
	and  ebp, 111b    ; SIB Base value
	cmp  ebp, 101b    ; is Base=101?
	je  .disp32
	jmp .lastByte
.disp8:
	mov  esi, disp8value
	or   esi, 0x90909000
	jmp .lastByte
.disp32:
	mov  esi, disp32value
	jmp .lastByte

	; the last byte of LEA
.lastByte:
	mov  bh, 0x90
	test eax, 0x10000 ; SIB present?
	jz  .return
	mov  [es:0], esi  ; take last byte of displacement dword
	mov  bh, [es:3]

.return:
	ret


addr32CalcCMPValues:
	mov bl, al
	shr bl, 3
	and bl, 00000111b ; CMP R/M value = dest register of LEA
	or  bl, 00111000b ; CMP Opcode value = /7 (CMP r/m32,imm32 inst.)
	or  bl, 11000000b ; CMP Mod value = 11b (dest is register)

	xor edx, edx

	; calculate the cmp value address offset in the values tables
	; EBP = will be the base address in the values tables
	; EDX = will be the index in the values tables (then mult. by 4 bytes)

	; take cmp value from the ModRM table
	; cmp value at cs:[testModRMValues + al*4]
	mov dl, al
	and dl, 0x7 ; R/M
	mov dh, al
	shr dh, 6   ; Mod
	shl dh, 3   ; Mod*8
	add dl, dh  ; DL = Mod*8 + R/M
	mov ebp, addr32Values

	test eax, 0x10000 ; is SIB used?
	jz .return

	; take cmp value from the SIB tables
	; cmp value at cs:[testModRMValuesSIB00 + 1024*SIBtblIdx + ah*4]
	mov dl, ah
	mov ebp, eax
	shr ebp, 6
	and ebp, 11b  ; SIBtblIdx (SIB table index)
	shl ebp, 10   ; 256values * 4bytes
	add ebp, addr32ValuesSIB00 ; SIB tables base

.return:
	ret


addr32CalcMOVValues:
	mov dh, al
	and dh, 00111000b ; MOV Reg value = Reg of LEA's ModRM
	or  dh, 00000101b ; MOV R/M value = disp32
	;or  dh, 00000000b ; MOV Mod value = 00b (dest is memory)
	ret


addr32CopyValues:
	mov [leaModRMOff],    al
	mov [leaSIBDispOff],  ah
	mov [edi],            esi
	mov [leaLastByteOff], bh
	mov [cmpModRMOff],    bl
	mov [movModRMOff],    dh
	and edx, 0xFF
	mov edx, [cs:ebp + edx*4]
	mov [cmpImm32Off],    edx
	ret


addr32PrintStatus:
	call printEAX
	;xchg ecx, edx
	;call printEDX
	;xchg ecx, edx
	;call printEOL
	ret


addr32PrintResult:
	push eax
	mov  eax, [es:0]
	call printEAX
	call printEOL
	pop  eax
	ret

; These are the values of the results of the LEA operation to be compared.
; ModRM values C0 - FF are not valid for LEA (#UD)
addr32Values:     ; ModRM value
	dd 0x00000001 ; 00 08 10 18 20 28 30 38
	dd 0x00000004 ; 01 09 11 19 21 29 31 39
	dd 0x00000008 ; 02 0A 12 1A 22 2A 32 3A
	dd 0x00000002 ; 03 0B 13 1B 23 2B 33 3B
	dd 0x0 ; SIB00  04 0C 14 1C 24 2C 34 3C
	dd 0x80000000 ; 05 0D 15 1D 25 2D 35 3D
	dd 0x00000080 ; 06 0E 16 1E 26 2E 36 3E
	dd 0x00000100 ; 07 0F 17 1F 27 2F 37 3F
	dd 0xFFFFFF81 ; 40 48 50 58 60 68 70 78
	dd 0xFFFFFF84 ; 41 49 51 59 61 69 71 79
	dd 0xFFFFFF88 ; 42 4A 52 5A 62 6A 72 7A
	dd 0xFFFFFF82 ; 43 4B 53 5B 63 6B 73 7B
	dd 0x0 ; SIB01  44 4C 54 5C 64 6C 74 7C
	dd 0xFFFFFFC0 ; 45 4D 55 5D 65 6D 75 7D
	dd 0x00000000 ; 46 4E 56 5E 66 6E 76 7E
	dd 0x00000080 ; 47 4F 57 5F 67 6F 77 7F
	dd 0x80000001 ; 80 88 90 98 A0 A8 B0 B8
	dd 0x80000004 ; 81 89 91 99 A1 A9 B1 B9
	dd 0x80000008 ; 82 8A 92 9A A2 AA B2 BA
	dd 0x80000002 ; 83 8B 93 9B A3 AB B3 BB
	dd 0x0 ; SIB10  84 8C 94 9C A4 AC B4 BC
	dd 0x80000040 ; 85 8D 95 9D A5 AD B5 BD
	dd 0x80000080 ; 86 8E 96 9E A6 AE B6 BE
	dd 0x80000100 ; 87 8F 97 9F A7 AF B7 BF
addr32ValuesSIB00: ; SIB values
	dd 0x00000002  ; 00 
	dd 0x00000005  ; 01 
	dd 0x00000009  ; 02 
	dd 0x00000003  ; 03 
	dd 0x00000021  ; 04 
	dd 0x80000001  ; 05 
	dd 0x00000081  ; 06 
	dd 0x00000101  ; 07 
	dd 0x00000005  ; 08 
	dd 0x00000008  ; 09 
	dd 0x0000000C  ; 0A 
	dd 0x00000006  ; 0B 
	dd 0x00000024  ; 0C 
	dd 0x80000004  ; 0D 
	dd 0x00000084  ; 0E 
	dd 0x00000104  ; 0F 
	dd 0x00000009  ; 10
	dd 0x0000000C  ; 11
	dd 0x00000010  ; 12
	dd 0x0000000A  ; 13
	dd 0x00000028  ; 14
	dd 0x80000008  ; 15
	dd 0x00000088  ; 16
	dd 0x00000108  ; 17
	dd 0x00000003  ; 18
	dd 0x00000006  ; 19
	dd 0x0000000A  ; 1A
	dd 0x00000004  ; 1B
	dd 0x00000022  ; 1C
	dd 0x80000002  ; 1D
	dd 0x00000082  ; 1E
	dd 0x00000102  ; 1F
	dd 0x00000001  ; 20
	dd 0x00000004  ; 21
	dd 0x00000008  ; 22
	dd 0x00000002  ; 23
	dd 0x00000020  ; 24
	dd 0x80000000  ; 25
	dd 0x00000080  ; 26
	dd 0x00000100  ; 27
	dd 0x00000041  ; 28
	dd 0x00000044  ; 29
	dd 0x00000048  ; 2A
	dd 0x00000042  ; 2B
	dd 0x00000060  ; 2C
	dd 0x80000040  ; 2D
	dd 0x000000C0  ; 2E
	dd 0x00000140  ; 2F
	dd 0x00000081  ; 30
	dd 0x00000084  ; 31
	dd 0x00000088  ; 32
	dd 0x00000082  ; 33
	dd 0x000000A0  ; 34
	dd 0x80000080  ; 35
	dd 0x00000100  ; 36
	dd 0x00000180  ; 37
	dd 0x00000101  ; 38
	dd 0x00000104  ; 39
	dd 0x00000108  ; 3A
	dd 0x00000102  ; 3B
	dd 0x00000120  ; 3C
	dd 0x80000100  ; 3D
	dd 0x00000180  ; 3E
	dd 0x00000200  ; 3F
	dd 0x00000003  ; 40
	dd 0x00000006  ; 41
	dd 0x0000000A  ; 42
	dd 0x00000004  ; 43
	dd 0x00000022  ; 44
	dd 0x80000002  ; 45
	dd 0x00000082  ; 46
	dd 0x00000102  ; 47
	dd 0x00000009  ; 48
	dd 0x0000000C  ; 49
	dd 0x00000010  ; 4A
	dd 0x0000000A  ; 4B
	dd 0x00000028  ; 4C
	dd 0x80000008  ; 4D
	dd 0x00000088  ; 4E
	dd 0x00000108  ; 4F
	dd 0x00000011  ; 50
	dd 0x00000014  ; 51
	dd 0x00000018  ; 52
	dd 0x00000012  ; 53
	dd 0x00000030  ; 54
	dd 0x80000010  ; 55
	dd 0x00000090  ; 56
	dd 0x00000110  ; 57
	dd 0x00000005  ; 58
	dd 0x00000008  ; 59
	dd 0x0000000C  ; 5A
	dd 0x00000006  ; 5B
	dd 0x00000024  ; 5C
	dd 0x80000004  ; 5D
	dd 0x00000084  ; 5E
	dd 0x00000104  ; 5F
	dd 0x00000002  ; 60 UB  EAX * 2
	dd 0x00000008  ; 61 UB  ECX * 2
	dd 0x00000010  ; 62 UB  EDX * 2
	dd 0x00000004  ; 63 UB  EBX * 2
	dd 0x00000040  ; 64 UB  ESP * 2
	dd 0x80000000  ; 65 UB  disp32
	dd 0x00000100  ; 66 UB  ESI * 2
	dd 0x00000200  ; 67 UB  EDI * 2
	dd 0x00000081  ; 68
	dd 0x00000084  ; 69
	dd 0x00000088  ; 6A
	dd 0x00000082  ; 6B
	dd 0x000000A0  ; 6C
	dd 0x80000080  ; 6D
	dd 0x00000100  ; 6E
	dd 0x00000180  ; 6F
	dd 0x00000101  ; 70
	dd 0x00000104  ; 71
	dd 0x00000108  ; 72
	dd 0x00000102  ; 73
	dd 0x00000120  ; 74
	dd 0x80000100  ; 75
	dd 0x00000180  ; 76
	dd 0x00000200  ; 77
	dd 0x00000201  ; 78
	dd 0x00000204  ; 79
	dd 0x00000208  ; 7A
	dd 0x00000202  ; 7B
	dd 0x00000220  ; 7C
	dd 0x80000200  ; 7D
	dd 0x00000280  ; 7E
	dd 0x00000300  ; 7F
	dd 0x00000005  ; 80
	dd 0x00000008  ; 81
	dd 0x0000000C  ; 82
	dd 0x00000006  ; 83
	dd 0x00000024  ; 84
	dd 0x80000004  ; 85
	dd 0x00000084  ; 86
	dd 0x00000104  ; 87
	dd 0x00000011  ; 88
	dd 0x00000014  ; 89
	dd 0x00000018  ; 8A
	dd 0x00000012  ; 8B
	dd 0x00000030  ; 8C
	dd 0x80000010  ; 8D
	dd 0x00000090  ; 8E
	dd 0x00000110  ; 8F
	dd 0x00000021  ; 90
	dd 0x00000024  ; 91
	dd 0x00000028  ; 92
	dd 0x00000022  ; 93
	dd 0x00000040  ; 94
	dd 0x80000020  ; 95
	dd 0x000000A0  ; 96
	dd 0x00000120  ; 97
	dd 0x00000009  ; 98
	dd 0x0000000C  ; 99
	dd 0x00000010  ; 9A
	dd 0x0000000A  ; 9B
	dd 0x00000028  ; 9C
	dd 0x80000008  ; 9D
	dd 0x00000088  ; 9E
	dd 0x00000108  ; 9F
	dd 0x00000004  ; A0 UB  EAX * 4
	dd 0x00000010  ; A1 UB  ECX * 4
	dd 0x00000020  ; A2 UB  EDX * 4
	dd 0x00000008  ; A3 UB  EBX * 4
	dd 0x00000080  ; A4 UB  ESP * 4
	dd 0x80000000  ; A5 UB  disp32 
	dd 0x00000200  ; A6 UB  ESI * 4
	dd 0x00000400  ; A7 UB  EDI * 4
	dd 0x00000101  ; A8
	dd 0x00000104  ; A9
	dd 0x00000108  ; AA
	dd 0x00000102  ; AB
	dd 0x00000120  ; AC
	dd 0x80000100  ; AD
	dd 0x00000180  ; AE
	dd 0x00000200  ; AF
	dd 0x00000201  ; B0
	dd 0x00000204  ; B1
	dd 0x00000208  ; B2
	dd 0x00000202  ; B3
	dd 0x00000220  ; B4
	dd 0x80000200  ; B5
	dd 0x00000280  ; B6
	dd 0x00000300  ; B7
	dd 0x00000401  ; B8
	dd 0x00000404  ; B9
	dd 0x00000408  ; BA
	dd 0x00000402  ; BB
	dd 0x00000420  ; BC
	dd 0x80000400  ; BD
	dd 0x00000480  ; BE
	dd 0x00000500  ; BF
	dd 0x00000009  ; C0
	dd 0x0000000C  ; C1
	dd 0x00000010  ; C2
	dd 0x0000000A  ; C3
	dd 0x00000028  ; C4
	dd 0x80000008  ; C5
	dd 0x00000088  ; C6
	dd 0x00000108  ; C7
	dd 0x00000021  ; C8
	dd 0x00000024  ; C9
	dd 0x00000028  ; CA
	dd 0x00000022  ; CB
	dd 0x00000040  ; CC
	dd 0x80000020  ; CD
	dd 0x000000A0  ; CE
	dd 0x00000120  ; CF
	dd 0x00000041  ; D0
	dd 0x00000044  ; D1
	dd 0x00000048  ; D2
	dd 0x00000042  ; D3
	dd 0x00000060  ; D4
	dd 0x80000040  ; D5
	dd 0x000000C0  ; D6
	dd 0x00000140  ; D7
	dd 0x00000011  ; D8
	dd 0x00000014  ; D9
	dd 0x00000018  ; DA
	dd 0x00000012  ; DB
	dd 0x00000030  ; DC
	dd 0x80000010  ; DD
	dd 0x00000090  ; DE
	dd 0x00000110  ; DF
	dd 0x00000008  ; E0 UB  EAX * 8
	dd 0x00000020  ; E1 UB  ECX * 8
	dd 0x00000040  ; E2 UB  EDX * 8
	dd 0x00000010  ; E3 UB  EBX * 8
	dd 0x00000100  ; E4 UB  ESP * 8
	dd 0x80000000  ; E5 UB  disp32 
	dd 0x00000400  ; E6 UB  ESI * 8
	dd 0x00000800  ; E7 UB  EDI * 8
	dd 0x00000201  ; E8
	dd 0x00000204  ; E9
	dd 0x00000208  ; EA
	dd 0x00000202  ; EB
	dd 0x00000220  ; EC
	dd 0x80000200  ; ED
	dd 0x00000280  ; EE
	dd 0x00000300  ; EF
	dd 0x00000401  ; F0
	dd 0x00000404  ; F1
	dd 0x00000408  ; F2
	dd 0x00000402  ; F3
	dd 0x00000420  ; F4
	dd 0x80000400  ; F5
	dd 0x00000480  ; F6
	dd 0x00000500  ; F7
	dd 0x00000801  ; F8
	dd 0x00000804  ; F9
	dd 0x00000808  ; FA
	dd 0x00000802  ; FB
	dd 0x00000820  ; FC
	dd 0x80000800  ; FD
	dd 0x00000880  ; FE
	dd 0x00000900  ; FF
addr32ValuesSIB01: ; MOD = 01
	dd 0xFFFFFF82  ; 00
	dd 0xFFFFFF85  ; 01
	dd 0xFFFFFF89  ; 02
	dd 0xFFFFFF83  ; 03
	dd 0xFFFFFFA1  ; 04
	dd 0xFFFFFFC1  ; 05
	dd 0x00000001  ; 06
	dd 0x00000081  ; 07
	dd 0xFFFFFF85  ; 08
	dd 0xFFFFFF88  ; 09
	dd 0xFFFFFF8C  ; 0A
	dd 0xFFFFFF86  ; 0B
	dd 0xFFFFFFA4  ; 0C
	dd 0xFFFFFFC4  ; 0D
	dd 0x00000004  ; 0E
	dd 0x00000084  ; 0F
	dd 0xFFFFFF89  ; 10
	dd 0xFFFFFF8C  ; 11
	dd 0xFFFFFF90  ; 12
	dd 0xFFFFFF8A  ; 13
	dd 0xFFFFFFA8  ; 14
	dd 0xFFFFFFC8  ; 15
	dd 0x00000008  ; 16
	dd 0x00000088  ; 17
	dd 0xFFFFFF83  ; 18
	dd 0xFFFFFF86  ; 19
	dd 0xFFFFFF8A  ; 1A
	dd 0xFFFFFF84  ; 1B
	dd 0xFFFFFFA2  ; 1C
	dd 0xFFFFFFC2  ; 1D
	dd 0x00000002  ; 1E
	dd 0x00000082  ; 1F
	dd 0xFFFFFF81  ; 20
	dd 0xFFFFFF84  ; 21
	dd 0xFFFFFF88  ; 22
	dd 0xFFFFFF82  ; 23
	dd 0xFFFFFFA0  ; 24
	dd 0xFFFFFFC0  ; 25
	dd 0x00000000  ; 26
	dd 0x00000080  ; 27
	dd 0xFFFFFFC1  ; 28
	dd 0xFFFFFFC4  ; 29
	dd 0xFFFFFFC8  ; 2A
	dd 0xFFFFFFC2  ; 2B
	dd 0xFFFFFFE0  ; 2C
	dd 0x00000000  ; 2D
	dd 0x00000040  ; 2E
	dd 0x000000C0  ; 2F
	dd 0x00000001  ; 30
	dd 0x00000004  ; 31
	dd 0x00000008  ; 32
	dd 0x00000002  ; 33
	dd 0x00000020  ; 34
	dd 0x00000040  ; 35
	dd 0x00000080  ; 36
	dd 0x00000100  ; 37
	dd 0x00000081  ; 38
	dd 0x00000084  ; 39
	dd 0x00000088  ; 3A
	dd 0x00000082  ; 3B
	dd 0x000000A0  ; 3C
	dd 0x000000C0  ; 3D
	dd 0x00000100  ; 3E
	dd 0x00000180  ; 3F
	dd 0xFFFFFF83  ; 40
	dd 0xFFFFFF86  ; 41
	dd 0xFFFFFF8A  ; 42
	dd 0xFFFFFF84  ; 43
	dd 0xFFFFFFA2  ; 44
	dd 0xFFFFFFC2  ; 45
	dd 0x00000002  ; 46
	dd 0x00000082  ; 47
	dd 0xFFFFFF89  ; 48
	dd 0xFFFFFF8C  ; 49
	dd 0xFFFFFF90  ; 4A
	dd 0xFFFFFF8A  ; 4B
	dd 0xFFFFFFA8  ; 4C
	dd 0xFFFFFFC8  ; 4D
	dd 0x00000008  ; 4E
	dd 0x00000088  ; 4F
	dd 0xFFFFFF91  ; 50
	dd 0xFFFFFF94  ; 51
	dd 0xFFFFFF98  ; 52
	dd 0xFFFFFF92  ; 53
	dd 0xFFFFFFB0  ; 54
	dd 0xFFFFFFD0  ; 55
	dd 0x00000010  ; 56
	dd 0x00000090  ; 57
	dd 0xFFFFFF85  ; 58
	dd 0xFFFFFF88  ; 59
	dd 0xFFFFFF8C  ; 5A
	dd 0xFFFFFF86  ; 5B
	dd 0xFFFFFFA4  ; 5C
	dd 0xFFFFFFC4  ; 5D
	dd 0x00000004  ; 5E
	dd 0x00000084  ; 5F
	dd 0xFFFFFF82  ; 60 UB  disp8 + EAX * 2
	dd 0xFFFFFF88  ; 61 UB  disp8 + ECX * 2
	dd 0xFFFFFF90  ; 62 UB  disp8 + EDX * 2
	dd 0xFFFFFF84  ; 63 UB  disp8 + EBX * 2
	dd 0xFFFFFFC0  ; 64 UB  disp8 + ESP * 2
	dd 0x00000000  ; 65 UB  disp8 + EBP * 2
	dd 0x00000080  ; 66 UB  disp8 + ESI * 2
	dd 0x00000180  ; 67 UB  disp8 + EDI * 2
	dd 0x00000001  ; 68
	dd 0x00000004  ; 69
	dd 0x00000008  ; 6A
	dd 0x00000002  ; 6B
	dd 0x00000020  ; 6C
	dd 0x00000040  ; 6D
	dd 0x00000080  ; 6E
	dd 0x00000100  ; 6F
	dd 0x00000081  ; 70
	dd 0x00000084  ; 71
	dd 0x00000088  ; 72
	dd 0x00000082  ; 73
	dd 0x000000A0  ; 74
	dd 0x000000C0  ; 75
	dd 0x00000100  ; 76
	dd 0x00000180  ; 77
	dd 0x00000181  ; 78
	dd 0x00000184  ; 79
	dd 0x00000188  ; 7A
	dd 0x00000182  ; 7B
	dd 0x000001A0  ; 7C
	dd 0x000001C0  ; 7D
	dd 0x00000200  ; 7E
	dd 0x00000280  ; 7F
	dd 0xFFFFFF85  ; 80
	dd 0xFFFFFF88  ; 81
	dd 0xFFFFFF8C  ; 82
	dd 0xFFFFFF86  ; 83
	dd 0xFFFFFFA4  ; 84
	dd 0xFFFFFFC4  ; 85
	dd 0x00000004  ; 86
	dd 0x00000084  ; 87
	dd 0xFFFFFF91  ; 88
	dd 0xFFFFFF94  ; 89
	dd 0xFFFFFF98  ; 8A
	dd 0xFFFFFF92  ; 8B
	dd 0xFFFFFFB0  ; 8C
	dd 0xFFFFFFD0  ; 8D
	dd 0x00000010  ; 8E
	dd 0x00000090  ; 8F
	dd 0xFFFFFFA1  ; 90
	dd 0xFFFFFFA4  ; 91
	dd 0xFFFFFFA8  ; 92
	dd 0xFFFFFFA2  ; 93
	dd 0xFFFFFFC0  ; 94
	dd 0xFFFFFFE0  ; 95
	dd 0x00000020  ; 96
	dd 0x000000A0  ; 97
	dd 0xFFFFFF89  ; 98
	dd 0xFFFFFF8C  ; 99
	dd 0xFFFFFF90  ; 9A
	dd 0xFFFFFF8A  ; 9B
	dd 0xFFFFFFA8  ; 9C
	dd 0xFFFFFFC8  ; 9D
	dd 0x00000008  ; 9E
	dd 0x00000088  ; 9F
	dd 0xFFFFFF84  ; A0 UB  disp8 + EAX * 4
	dd 0xFFFFFF90  ; A1 UB  disp8 + ECX * 4
	dd 0xFFFFFFA0  ; A2 UB  disp8 + EDX * 4
	dd 0xFFFFFF88  ; A3 UB  disp8 + EBX * 4
	dd 0x00000000  ; A4 UB  disp8 + ESP * 4
	dd 0x00000080  ; A5 UB  disp8 + EBP * 4
	dd 0x00000180  ; A6 UB  disp8 + ESI * 4
	dd 0x00000380  ; A7 UB  disp8 + EDI * 4
	dd 0x00000081  ; A8
	dd 0x00000084  ; A9
	dd 0x00000088  ; AA
	dd 0x00000082  ; AB
	dd 0x000000A0  ; AC
	dd 0x000000C0  ; AD
	dd 0x00000100  ; AE
	dd 0x00000180  ; AF
	dd 0x00000181  ; B0
	dd 0x00000184  ; B1
	dd 0x00000188  ; B2
	dd 0x00000182  ; B3
	dd 0x000001A0  ; B4
	dd 0x000001C0  ; B5
	dd 0x00000200  ; B6
	dd 0x00000280  ; B7
	dd 0x00000381  ; B8
	dd 0x00000384  ; B9
	dd 0x00000388  ; BA
	dd 0x00000382  ; BB
	dd 0x000003A0  ; BC
	dd 0x000003C0  ; BD
	dd 0x00000400  ; BE
	dd 0x00000480  ; BF
	dd 0xFFFFFF89  ; C0
	dd 0xFFFFFF8C  ; C1
	dd 0xFFFFFF90  ; C2
	dd 0xFFFFFF8A  ; C3
	dd 0xFFFFFFA8  ; C4
	dd 0xFFFFFFC8  ; C5
	dd 0x00000008  ; C6
	dd 0x00000088  ; C7
	dd 0xFFFFFFA1  ; C8
	dd 0xFFFFFFA4  ; C9
	dd 0xFFFFFFA8  ; CA
	dd 0xFFFFFFA2  ; CB
	dd 0xFFFFFFC0  ; CC
	dd 0xFFFFFFE0  ; CD
	dd 0x00000020  ; CE
	dd 0x000000A0  ; CF
	dd 0xFFFFFFC1  ; D0
	dd 0xFFFFFFC4  ; D1
	dd 0xFFFFFFC8  ; D2
	dd 0xFFFFFFC2  ; D3
	dd 0xFFFFFFE0  ; D4
	dd 0x00000000  ; D5
	dd 0x00000040  ; D6
	dd 0x000000C0  ; D7
	dd 0xFFFFFF91  ; D8
	dd 0xFFFFFF94  ; D9
	dd 0xFFFFFF98  ; DA
	dd 0xFFFFFF92  ; DB
	dd 0xFFFFFFB0  ; DC
	dd 0xFFFFFFD0  ; DD
	dd 0x00000010  ; DE
	dd 0x00000090  ; DF
	dd 0xFFFFFF88  ; E0 UB  disp8 + EAX * 8
	dd 0xFFFFFFA0  ; E1 UB  disp8 + ECX * 8
	dd 0xFFFFFFC0  ; E2 UB  disp8 + EDX * 8
	dd 0xFFFFFF90  ; E3 UB  disp8 + EBX * 8
	dd 0x00000080  ; E4 UB  disp8 + ESP * 8
	dd 0x00000180  ; E5 UB  disp8 + EBP * 8
	dd 0x00000380  ; E6 UB  disp8 + ESI * 8
	dd 0x00000780  ; E7 UB  disp8 + EDI * 8
	dd 0x00000181  ; E8
	dd 0x00000184  ; E9
	dd 0x00000188  ; EA
	dd 0x00000182  ; EB
	dd 0x000001A0  ; EC
	dd 0x000001C0  ; ED
	dd 0x00000200  ; EE
	dd 0x00000280  ; EF
	dd 0x00000381  ; F0
	dd 0x00000384  ; F1
	dd 0x00000388  ; F2
	dd 0x00000382  ; F3
	dd 0x000003A0  ; F4
	dd 0x000003C0  ; F5
	dd 0x00000400  ; F6
	dd 0x00000480  ; F7
	dd 0x00000781  ; F8
	dd 0x00000784  ; F9
	dd 0x00000788  ; FA
	dd 0x00000782  ; FB
	dd 0x000007A0  ; FC
	dd 0x000007C0  ; FD
	dd 0x00000800  ; FE
	dd 0x00000880  ; FF
addr32ValuesSIB10:
	dd 0x80000002  ; 00
	dd 0x80000005  ; 01
	dd 0x80000009  ; 02
	dd 0x80000003  ; 03
	dd 0x80000021  ; 04
	dd 0x80000041  ; 05
	dd 0x80000081  ; 06
	dd 0x80000101  ; 07
	dd 0x80000005  ; 08
	dd 0x80000008  ; 09
	dd 0x8000000C  ; 0A
	dd 0x80000006  ; 0B
	dd 0x80000024  ; 0C
	dd 0x80000044  ; 0D
	dd 0x80000084  ; 0E
	dd 0x80000104  ; 0F
	dd 0x80000009  ; 10
	dd 0x8000000C  ; 11
	dd 0x80000010  ; 12
	dd 0x8000000A  ; 13
	dd 0x80000028  ; 14
	dd 0x80000048  ; 15
	dd 0x80000088  ; 16
	dd 0x80000108  ; 17
	dd 0x80000003  ; 18
	dd 0x80000006  ; 19
	dd 0x8000000A  ; 1A
	dd 0x80000004  ; 1B
	dd 0x80000022  ; 1C
	dd 0x80000042  ; 1D
	dd 0x80000082  ; 1E
	dd 0x80000102  ; 1F
	dd 0x80000001  ; 20
	dd 0x80000004  ; 21
	dd 0x80000008  ; 22
	dd 0x80000002  ; 23
	dd 0x80000020  ; 24
	dd 0x80000040  ; 25
	dd 0x80000080  ; 26
	dd 0x80000100  ; 27
	dd 0x80000041  ; 28
	dd 0x80000044  ; 29
	dd 0x80000048  ; 2A
	dd 0x80000042  ; 2B
	dd 0x80000060  ; 2C
	dd 0x80000080  ; 2D
	dd 0x800000C0  ; 2E
	dd 0x80000140  ; 2F
	dd 0x80000081  ; 30
	dd 0x80000084  ; 31
	dd 0x80000088  ; 32
	dd 0x80000082  ; 33
	dd 0x800000A0  ; 34
	dd 0x800000C0  ; 35
	dd 0x80000100  ; 36
	dd 0x80000180  ; 37
	dd 0x80000101  ; 38
	dd 0x80000104  ; 39
	dd 0x80000108  ; 3A
	dd 0x80000102  ; 3B
	dd 0x80000120  ; 3C
	dd 0x80000140  ; 3D
	dd 0x80000180  ; 3E
	dd 0x80000200  ; 3F
	dd 0x80000003  ; 40
	dd 0x80000006  ; 41
	dd 0x8000000A  ; 42
	dd 0x80000004  ; 43
	dd 0x80000022  ; 44
	dd 0x80000042  ; 45
	dd 0x80000082  ; 46
	dd 0x80000102  ; 47
	dd 0x80000009  ; 48
	dd 0x8000000C  ; 49
	dd 0x80000010  ; 4A
	dd 0x8000000A  ; 4B
	dd 0x80000028  ; 4C
	dd 0x80000048  ; 4D
	dd 0x80000088  ; 4E
	dd 0x80000108  ; 4F
	dd 0x80000011  ; 50
	dd 0x80000014  ; 51
	dd 0x80000018  ; 52
	dd 0x80000012  ; 53
	dd 0x80000030  ; 54
	dd 0x80000050  ; 55
	dd 0x80000090  ; 56
	dd 0x80000110  ; 57
	dd 0x80000005  ; 58
	dd 0x80000008  ; 59
	dd 0x8000000C  ; 5A
	dd 0x80000006  ; 5B
	dd 0x80000024  ; 5C
	dd 0x80000044  ; 5D
	dd 0x80000084  ; 5E
	dd 0x80000104  ; 5F
	dd 0x80000002  ; 60 UB  disp32 + EAX * 2
	dd 0x80000008  ; 61 UB  disp32 + ECX * 2
	dd 0x80000010  ; 62 UB  disp32 + EDX * 2
	dd 0x80000004  ; 63 UB  disp32 + EBX * 2
	dd 0x80000040  ; 64 UB  disp32 + ESP * 2
	dd 0x80000080  ; 65 UB  disp32 + EBP * 2
	dd 0x80000100  ; 66 UB  disp32 + ESI * 2
	dd 0x80000200  ; 67 UB  disp32 + EDI * 2
	dd 0x80000081  ; 68
	dd 0x80000084  ; 69
	dd 0x80000088  ; 6A
	dd 0x80000082  ; 6B
	dd 0x800000A0  ; 6C
	dd 0x800000C0  ; 6D
	dd 0x80000100  ; 6E
	dd 0x80000180  ; 6F
	dd 0x80000101  ; 70
	dd 0x80000104  ; 71
	dd 0x80000108  ; 72
	dd 0x80000102  ; 73
	dd 0x80000120  ; 74
	dd 0x80000140  ; 75
	dd 0x80000180  ; 76
	dd 0x80000200  ; 77
	dd 0x80000201  ; 78
	dd 0x80000204  ; 79
	dd 0x80000208  ; 7A
	dd 0x80000202  ; 7B
	dd 0x80000220  ; 7C
	dd 0x80000240  ; 7D
	dd 0x80000280  ; 7E
	dd 0x80000300  ; 7F
	dd 0x80000005  ; 80
	dd 0x80000008  ; 81
	dd 0x8000000C  ; 82
	dd 0x80000006  ; 83
	dd 0x80000024  ; 84
	dd 0x80000044  ; 85
	dd 0x80000084  ; 86
	dd 0x80000104  ; 87
	dd 0x80000011  ; 88
	dd 0x80000014  ; 89
	dd 0x80000018  ; 8A
	dd 0x80000012  ; 8B
	dd 0x80000030  ; 8C
	dd 0x80000050  ; 8D
	dd 0x80000090  ; 8E
	dd 0x80000110  ; 8F
	dd 0x80000021  ; 90
	dd 0x80000024  ; 91
	dd 0x80000028  ; 92
	dd 0x80000022  ; 93
	dd 0x80000040  ; 94
	dd 0x80000060  ; 95
	dd 0x800000A0  ; 96
	dd 0x80000120  ; 97
	dd 0x80000009  ; 98
	dd 0x8000000C  ; 99
	dd 0x80000010  ; 9A
	dd 0x8000000A  ; 9B
	dd 0x80000028  ; 9C
	dd 0x80000048  ; 9D
	dd 0x80000088  ; 9E
	dd 0x80000108  ; 9F
	dd 0x80000004  ; A0 UB  disp32 + EAX * 4
	dd 0x80000010  ; A1 UB  disp32 + ECX * 4
	dd 0x80000020  ; A2 UB  disp32 + EDX * 4
	dd 0x80000008  ; A3 UB  disp32 + EBX * 4
	dd 0x80000080  ; A4 UB  disp32 + ESP * 4
	dd 0x80000100  ; A5 UB  disp32 + EBP * 4
	dd 0x80000200  ; A6 UB  disp32 + ESI * 4
	dd 0x80000400  ; A7 UB  disp32 + EDI * 4
	dd 0x80000101  ; A8
	dd 0x80000104  ; A9
	dd 0x80000108  ; AA
	dd 0x80000102  ; AB
	dd 0x80000120  ; AC
	dd 0x80000140  ; AD
	dd 0x80000180  ; AE
	dd 0x80000200  ; AF
	dd 0x80000201  ; B0
	dd 0x80000204  ; B1
	dd 0x80000208  ; B2
	dd 0x80000202  ; B3
	dd 0x80000220  ; B4
	dd 0x80000240  ; B5
	dd 0x80000280  ; B6
	dd 0x80000300  ; B7
	dd 0x80000401  ; B8
	dd 0x80000404  ; B9
	dd 0x80000408  ; BA
	dd 0x80000402  ; BB
	dd 0x80000420  ; BC
	dd 0x80000440  ; BD
	dd 0x80000480  ; BE
	dd 0x80000500  ; BF
	dd 0x80000009  ; C0
	dd 0x8000000C  ; C1
	dd 0x80000010  ; C2
	dd 0x8000000A  ; C3
	dd 0x80000028  ; C4
	dd 0x80000048  ; C5
	dd 0x80000088  ; C6
	dd 0x80000108  ; C7
	dd 0x80000021  ; C8
	dd 0x80000024  ; C9
	dd 0x80000028  ; CA
	dd 0x80000022  ; CB
	dd 0x80000040  ; CC
	dd 0x80000060  ; CD
	dd 0x800000A0  ; CE
	dd 0x80000120  ; CF
	dd 0x80000041  ; D0
	dd 0x80000044  ; D1
	dd 0x80000048  ; D2
	dd 0x80000042  ; D3
	dd 0x80000060  ; D4
	dd 0x80000080  ; D5
	dd 0x800000C0  ; D6
	dd 0x80000140  ; D7
	dd 0x80000011  ; D8
	dd 0x80000014  ; D9
	dd 0x80000018  ; DA
	dd 0x80000012  ; DB
	dd 0x80000030  ; DC
	dd 0x80000050  ; DD
	dd 0x80000090  ; DE
	dd 0x80000110  ; DF
	dd 0x80000008  ; E0 UB  disp32 + EAX * 8
	dd 0x80000020  ; E1 UB  disp32 + ECX * 8
	dd 0x80000040  ; E2 UB  disp32 + EDX * 8
	dd 0x80000010  ; E3 UB  disp32 + EBX * 8
	dd 0x80000100  ; E4 UB  disp32 + ESP * 8
	dd 0x80000200  ; E5 UB  disp32 + EBP * 8
	dd 0x80000400  ; E6 UB  disp32 + ESI * 8
	dd 0x80000800  ; E7 UB  disp32 + EDI * 8
	dd 0x80000201  ; E8
	dd 0x80000204  ; E9
	dd 0x80000208  ; EA
	dd 0x80000202  ; EB
	dd 0x80000220  ; EC
	dd 0x80000240  ; ED
	dd 0x80000280  ; EE
	dd 0x80000300  ; EF
	dd 0x80000401  ; F0
	dd 0x80000404  ; F1
	dd 0x80000408  ; F2
	dd 0x80000402  ; F3
	dd 0x80000420  ; F4
	dd 0x80000440  ; F5
	dd 0x80000480  ; F6
	dd 0x80000500  ; F7
	dd 0x80000801  ; F8
	dd 0x80000804  ; F9
	dd 0x80000808  ; FA
	dd 0x80000802  ; FB
	dd 0x80000820  ; FC
	dd 0x80000840  ; FD
	dd 0x80000880  ; FE
	dd 0x80000900  ; FF
