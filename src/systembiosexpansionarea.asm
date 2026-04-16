	; Protected mode prototype support to support GDT entry references in the remainder of the code
%include "protected_m.asm"
	; Always start with the NULL segment selector.
	defGDTDescPrototype NULL
	defGDTDescPrototype LDT_SEG_PROT
	defGDTDescPrototype LDT_SEG_PROT286
	defGDTDescPrototype DU_SEG_PROT32FLAT
	defGDTDescPrototype TSS_DSEG_PROT
	defGDTDescPrototype TSS_DSEG_PROT16
	defGDTDescPrototype TSS_PROT
	defGDTDescPrototype TSS_PROT16
	defGDTDescPrototype TSS_GSEG_PROT32
	defGDTDescPrototype TSS_GSEG_PROT16
	defGDTDescPrototype CU_SEG_PROT32FLAT
	defGDTDescPrototype SU_SEG_PROT32DS
	defGDTDescPrototype SU_SEG_PROT32ES
	defGDTDescPrototype SU_SEG_PROT32FS
	defGDTDescPrototype SU_SEG_PROT32GS
	defGDTDescPrototype SU_SEG_PROT16SS
	defGDTDescPrototype SU_SEG_PROT16DS
	defGDTDescPrototype SU_SEG_PROT16ES
	defGDTDescPrototype CU_SEG_PROT16CS
	defGDTDescPrototype TSSU_DSEG_PROT32
	defGDTDescPrototype TSSU_DSEG_PROT16
	defGDTDescPrototype CU_SEG_PROT32
	defGDTDescPrototype C_SEG_PROT32_R2
	defGDTDescPrototype S_SEG_PROT32_R2
	defGDTDescPrototype C_SEG_PROT16CS

section .system_bios_extensions_area start=0x00000
;Start of high BIOS
	; TSS helper macros
%include "protected_tss_m.asm"
	;
	; TSS interrupt handlers
	;
%include "protected_tssinth.asm"
	;
	; 286 TSS handler
	;
%include "protected_tssh.asm"
BITS 32
	;
	; 386 TSS user mode code
	;
%include "protected_tsshelpers.asm"

test386TSSstart:
	; Verify we start clean
	setTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	setTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	setNTflag386 0,1,0
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT32,1,0
	validateTSSNT386 TSSU_DSEG_PROT16,0,0

	int 0x2A ;Validate 386 interrupts to Ring 2
	kernelModeInterruptR2Return:
	validateTSandClear 0 ;Expect no TS bit set yet.
	;Transfer the ring 0 stack from the 32-bit TSS to the 16-bit TSS to be able to call it and validate the TS flag.
	push ds
	push ebx
	push ecx
	lds ebx,[cs:ptrTSSprot_R2+0xE0000] ;Get the 32-bit TSS
	mov cx,[ebx+4] ;Get ring 0 ESP
	shl ecx,16 ;Move SP high
	mov cx,[ebx+8] ;Get ring 0 SS
	lds ebx,[cs:ptrTSSprot16_R2+0xE0000] ;Get the 16-bit TSS
	mov [ebx+4],cx ;Set ring 0 SS
	shr ecx,16 ;Move SP low
	mov [ebx+2],cx ;Set ring 0 SP
	pop ecx
	pop ebx
	pop ds
	;Loading patterns for the 386 data segments
	mov ax,SU_SEG_PROT32DS|3   ;DS
	mov ds,ax
	mov ax,SU_SEG_PROT32ES|3   ;ES
	mov es,ax
	mov ax,SU_SEG_PROT32FS|3   ;FS
	mov fs,ax
	mov ax,SU_SEG_PROT32GS|3   ;GS
	mov gs,ax
	
	;Loading patterns for the 386 data segments.
	mov eax,0x12347654
	mov ecx,0x5678CBA9
	mov edx,0x9ABC3333
	mov ebx,0xDEF02222
	mov esp,0x11221111
	mov ebp,0x33447777
	mov esi,0x55665555
	mov edi,0x7788AAAA
	clc ;Clear carry flag for the 286 test and us
	;Now, all test patterns are loaded. Trigger a switch to the 16-bit task.
	int 0x28
	;We've returned from the test task. Verify if our registers are loaded correctly.
	cmp esp,0x11221111      ;Validate the stack pointer first
	jnz errorInTSS32Load
	mov esp,ESP_R3_PROTFLAT ;Restore our stack pointer, so we regain stack functionality.
	cmp eax,0x12347654
	jnz error
	cmp ecx,0x5678CBA9
	jnz error
	cmp edx,0x9ABC3333
	jnz error
	cmp ebx,0xDEF02222
	jnz error
	cmp ebp,0x33447777
	jnz error
	cmp esi,0x55665555
	jnz error
	cmp edi,0x7788AAAA
	jnz error
	;Now, validate the segment registers
	mov ax,ss
	cmp ax,DU_SEG_PROT32FLAT|3 ;SS OK?
	jnz errorTSS32_1
	mov ax,cs
	cmp ax,CU_SEG_PROT32FLAT|3 ;CS OK?
	jnz errorTSS32_1
	mov ax,ds
	cmp ax,SU_SEG_PROT32DS|3   ;DS OK?
	jnz errorTSS32_1
	mov ax,es
	cmp ax,SU_SEG_PROT32ES|3   ;ES OK?
	jnz errorTSS32_1
	mov ax,fs
	cmp ax,SU_SEG_PROT32FS|3   ;FS OK?
	jnz errorTSS32_1
	mov ax,gs
	cmp ax,SU_SEG_PROT32GS|3   ;GS OK?
	jnz errorTSS32_1
	sldt ax
	cmp ax,LDT_SEG_PROT        ;LDT OK?
	jnz errorTSS16_1
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	jmp TSStest1finished
errorTSS32_1:
	mov ax,DU_SEG_PROT32FLAT|3  ;SS safe value
	mov ss,ax
	mov esp,ESP_R3_PROTFLAT   ;ESP safe value
	jmp error                  ;Error out	

TSStest1finished:
	;Now, we switch sides, to basic test JMP-based task switches
	jmp far [cs:ptrTSSprot16Gate+0xF0000]
	
	;Since basic task switches are validated now, we can start testing the various bits related to the task switches (Busy bit of the TSS, NT bit of the FLAGS register, Back-link field in the TSS)
	;80386 and 80486 programmer's reference manuals mention that the NT flag after a JMP instruction to another task is cleared. It is in fact, unaffected on 80386/80486 processors, due to a misprint of the manuals.

	;Start of the 32-bit to 16-bit TSS tests.
	;Step 1: validate 16-bit TSS outgoing/incoming B-bit, NT bit, Back-link during CALL.
	;First, setup initial task state.
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	setTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	setTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	setNTflag386 0,1,0
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT32,1,0
	validateTSSNT386 TSSU_DSEG_PROT16,0,0
	validateTSSNT386 0,1,0
	call far [cs:ptrTSSprot16Gate+0xF0000] ;TSS test 1: CALL busy bit set in both tasks, NT cleared to set, back-link filled by the CALL. Outgoing NT kept as-is (currently 0).
	;Now, setup the second test for call, this time with NT set.
	;First, validate IRET did it's job correctly. 
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,TSS_PROT
	validateTSSNT386 TSSU_DSEG_PROT32,1,0
	validateTSSNT386 TSSU_DSEG_PROT16,0,0
	;Reset state for detection.
	setTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	;Now, with NT bit set.
	setNTflag386 0,1,1
	call far [cs:ptrTSSprot16Gate+0xF0000] ;TSS test 2: CALL busy bit set in both tasks, NT set to set, back-link filled by the CALL. Outgoing NT kept as-is (currently 0).
	;Now, validate IRET did it's job correctly. 
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,TSS_PROT
	validateTSSNT386 TSSU_DSEG_PROT32,1,1
	validateTSSNT386 TSSU_DSEG_PROT16,0,0
	;Reset state for detection.
	setTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	;Now, the 32-bit task to 16-bit task backlink is properly filled, NT properly updating for CALL and matching IRET.
	;Now, test JMP instruction task switches.
	setNTflag386 0,1,1 ;This is going to be kept in the 32-bit TSS.
	setNTflag386 TSSU_DSEG_PROT32,1,0 ;This is going to be set to 1.
	setNTflag386 TSSU_DSEG_PROT16,0,0 ;This is going to be loaded.
	jmp far [cs:ptrTSSprot16Gate+0xF0000] ;TSS test 3.1: JMP busy bit set in 16-bit task, busy bit cleared in 32-bit task, NT unaffected, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT32,1,1
	validateTSSNT386 TSSU_DSEG_PROT16,0,0
	validateTSSNT386 0,1,1 ;The JMP instruction to our TSS cleared us.
	setNTflag386 0,1,0 ;This is going to be kept in the 32-bit TSS.
	setNTflag386 TSSU_DSEG_PROT32,1,1 ;This is going to be cleared.
	setNTflag386 TSSU_DSEG_PROT16,0,1 ;This is going to be loaded.
	jmp far [cs:ptrTSSprot16Gate+0xF0000] ;TSS test 3.2: JMP busy bit set in 16-bit task, busy bit cleared in 32-bit task, NT unaffected, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT32,1,0 ;Set to 0 in destination task.
	validateTSSNT386 TSSU_DSEG_PROT16,0,1 ;Left at 1.
	validateTSSNT386 0,1,0 ;Cleared currently in register only.

	;End of the 32-bit to 16-bit TSS tests. Now, switch sides to verify CALL from 16-bit to 32-bit.
	jmp far [cs:ptrTSSprot16Gate+0xF0000] ;Switch sides
	
	;Start of the 32-bit side of the 16-bit to 32-bit TSS tests.
	;TSS test 1: CALL busy bit set in both tasks, NT cleared to set, back-link filled by the CALL.
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,1
	validateTSSbacklink386 TSSU_DSEG_PROT32,TSS_PROT16
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT32,1,0 ;Not written yet, so left at 0.
	validateTSSNT386 TSSU_DSEG_PROT16,0,0
	validateTSSNT386 0,0,1 ;Set currently in register only.
	iretd ;Return to caller.
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT,1
	validateTSSbusy386 TSS_PROT16,1
	validateTSSbacklink386 TSSU_DSEG_PROT32,TSS_PROT16
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT16,0,1 ;Set to 1 in source task.
	validateTSSNT386 TSSU_DSEG_PROT32,1,0 ;Left at 0.
	validateTSSNT386 0,0,1 ;Set currently in register only.
	iretd ;Return to caller.
	;Now testing JMP from 32-bit task to 32-bit task, NT going from set to cleared in the source task. 32-bit task keeps it cleared.
	;TSS test 3: JMP busy bit set in 32-bit task, busy bit cleared in 16-bit task, NT in 386 task kept as-is, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	;TSS test 3.1: JMP busy bit set in 32-bit task, busy bit cleared in 16-bit task, NT in 386 task kept as-is, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbusy386 TSS_PROT,1
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT16,0,1 ;Set to 1 in source task.
	validateTSSNT386 TSSU_DSEG_PROT32,1,0 ;Loaded as 0.
	validateTSSNT386 0,1,0 ;Set in destination task from the TSS.
	jmp far [cs:ptrTSSprot16Gate+0xF0000] ;Return to the 16-bit task.
	;TSS test 3.2 Same as before, but NT in 286 is cleared.
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy386 TSS_PROT16,0
	validateTSSbusy386 TSS_PROT,1
	validateTSSbacklink386 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink386 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT386 TSSU_DSEG_PROT16,0,0 ;Set to 0 in source task.
	validateTSSNT386 TSSU_DSEG_PROT32,1,1 ;Loaded as 1.
	validateTSSNT386 0,1,1 ;Set in destination task from the TSS.
	setNTflag386 0,1,1 ;Set NT flag to test.
	jmp far [cs:ptrTSSprot16Gate+0xF0000] ;Return to the 16-bit task.

	;Now, we have switched sides to finish the tests.
	;We're the parent task again.

	;Start the V86 mode tests now. This task will be converted by the 16-bit task.
	setNTflag386 0,1,0 ;Clear the NT flag to test.
	jmp far [cs:ptrTSSprot16Gate+0xF0000] ;Return to the 16-bit task to convert us.
	BITS 16
	jmp noerror
	errorV86:
	cli ;Simply attempt to HLT
	hlt
	noerror:
	;Virtual 8086 mode now, if task switching did it's job.
	validateTSandClear 1 ;Validate TS bit is set properly.
	int 0x2D ;Are we actually in Virtual 8086 mode (from PL0, as we can't read VM directly)?
	push cs
	pop ax
	cmp ax,0xE000 ;Valid CS?
	jne errorV86
	push ss
	pop ax
	cmp ax,S_SEG_REAL ;Valid SS?
	jne errorV86
	push ds
	pop ax
	cmp ax,V86_DS ;Valid DS?
	jne errorV86
	push es
	pop ax
	cmp ax,V86_ES ;Valid ES?
	jne errorV86
	push fs
	pop ax
	cmp ax,V86_FS ;Valid FS?
	jne errorV86
	push gs
	pop ax
	cmp ax,V86_GS ;Valid GS?
	jne errorV86
	pushfd
	pop eax
	test eax,0x20000 ;VM bit is required to be cleared with IOPL=3?
	jnz errorV86

	int 0x28 ;Switch back to the 16-bit task to terminate V86 mode.

	;Finish up, we're back in flat user mode again. Return to the system BIOS.
	BITS 32
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	setNTflag386 0,1,0 ;Clear NT flag to finish.

	;32-bit eflags register loaded OK.
	push cs
	call nextlowbios
	nextlowbios:
	mov dword [esp],test386TSSend+0xF0000 ;Return to the F0000 segment in flat protected mode
	retfd ;Actually return
	
;End of high BIOS
	;Pad to 64KB
	times 0x10000-($-$$) nop
