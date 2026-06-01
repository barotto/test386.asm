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
	defGDTDescPrototype SU_SEG_PROT32
	defGDTDescPrototype C_SEG_PROT32low
	defGDTDescPrototype CC_SEG_PROT32low
	defGDTDescPrototype CU_SEG_PROT32low
	defGDTDescPrototype C_SEG_PROT32
	defGDTDescPrototype S_SEG_PROT32
	defGDTDescPrototype C_SEG_PROT32FLAT
;LDT entries
	defLDTDescPrototype D_SEG_PROT32
	defLDTDescPrototype DU_SEG_PROT
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
	; Interrupt handlers (installed during POST 8)
	;
%include "protected_inth.asm"
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

%include "tests/dtr_m.asm"
;Real mode code for these tests
BITS 16
XLATrealmodeError:
	push word 0xF000
	push word error
	retf
POST8_9_Aentrypoint:
;-------------------------------------------------------------------------------
	POST 1E
;-------------------------------------------------------------------------------
;
;   Load/save GDTR/IDTR in real mode
;
	testDTR 0,lidt,sidt
	testDTR 0,lgdt,sgdt
	testDTR 1,lidt,sidt
	testDTR 1,lgdt,sgdt


;-------------------------------------------------------------------------------
	POST 1F
;-------------------------------------------------------------------------------
;
;   XLAT in real mode
;
	;Test XLAT
	mov cx,0x100 ;Length of the lookup table.
	mov al,0x0 ;First entry
	mov bx,0 ;Initialize data pointer.
fillXLATLookupTable:
	neg al ;Store negated entries.
	mov [bx],al ;Create the lookup table entry.
	inc bx ;Next entry.
	neg al ;Restore negated entry.
	inc al
	loop fillXLATLookupTable
	mov cx,0x100 ;Length of the lookup table.
	mov bx,0 ;Initialize data pointer to the start of the table.
checkXLAT:
	mov ax,0x100 ;Calculate the entry we're going to check
	sub ax,cx ;Create the entry number to validate.
	mov dl,al ;Copy the entry number, as we're getting overwritten by the instruction.
	neg dl ;Convert the input to the expected result.
	xlat ;Execute the tested instruction
	cmp al,dl ;Is the result as expected?
	jnz XLATrealmodeError
	loop checkXLAT ;Check all input values.

;-------------------------------------------------------------------------------
	POST 7
;-------------------------------------------------------------------------------
;
;   Interrupts in real mode
;

	;Test real mode interrupts
	;First, install the interrupt handler.
	push ds
	mov ax,0
	mov ds,ax ;Point to the Interrupt Vector Table.
	;Set all real mode interupt handlers to an error vector.
	mov bx,0 ;Reset pointer
	mov cx,0x100 ;All interrupt vectors.
	jmp skipinterruptsclearing
nextRealModeInterruptSetError:
	;Set the interrupt to error
	mov word [bx+2],0xF000
	mov word [bx],error
	add bx,4 ;Next pointer
	loop nextRealModeInterruptSetError
	skipinterruptsclearing:
	;Set just our test interrupt vector.
	mov ax,cs
	mov [0x82],ax
	mov ax,realmodeInterrupt
	mov [0x80],ax
	pop ds
	;Now, call the real mode interrupt
	pushfd ;Save interrupts
	pushfd ;Modify flags
	or word [esp],PS_IF ;Enable interrupts and flags bits to test
	popfd
	mov eax,esp ;Stack pointer for the interrupt to check.
	int 0x20
	realmodeInterruptRET:
	popfd ;Restore interrupts
	;Return to the main lower BIOS.
	push word 0xF000
	push word POSTAreturnpoint
	retf

test386POST20start:	
;-------------------------------------------------------------------------------
	POST 20
;-------------------------------------------------------------------------------
;
;   Test user mode (ring 3) switching
;
	call far C_SEG_PROT32:clearTSSfar
	mov    ax, D_SEG_PROT32
	mov    ds, ax
	mov    es, ax
	mov    fs, ax
	mov    gs, ax
	pushfd

	; Test I/O port access permissions
	or     word [esp], 0x3000 ; Make I/O ports available on user mode
	popfd                     ; Make I/O ports availble now
	call   switchToRing3low      ; Switch to user mode (ring 3)
	in     al, 0x64           ; Read some I/O port freely
	call   switchToRing0low      ; Switch back to kernel mode (ring 0)
	; CS must be C_SEG_PROT32low|0 (CPL=0)
	mov    ax, cs
	cmp    ax, C_SEG_PROT32low
	jne    error
	pushfd
	and    word [esp], 0xFFF  ; Block ports on user mode again
	popfd
	call   switchToRing3low      ; back to user mode (ring 3) again
	; CS must be CU_SEG_PROT32low|3 (CPL=3)
	mov    ax, cs
	cmp    ax, CU_SEG_PROT32low|3
	jne    error
	; data segments must be NULL
	mov    ax, ds
	cmp    ax, 0
	jne    error
	mov    ax, es
	cmp    ax, 0
	jne    error
	mov    ax, fs
	cmp    ax, 0
	jne    error
	mov    ax, gs
	cmp    ax, 0
	jne    error

	; test privileged instructions in user mode (ring 3)
	protModeFaultTestLow EX_GP, 0, cli
	protModeFaultTestLow EX_GP, 0, hlt
	protModeFaultTestLow EX_GP, 0, in al,0x64

	; test invalid interrupt call
	protModeFaultTestLow EX_GP, 0x118|0x2, int 0x23

	; We should have the intial user mode stack setup right now for the below checks to validate.
	call   switchToRing0low      ; back to kernel mode (ring 0) again
	call   switchToRing3low      ; back to user mode (ring 3) again. Thus setting the Interrupt flag for our test.

	; Interrupt from user mode to kernel mode using a 32-bit interrupt gate
	%if ROM128
	int   0x20
kernelModeInterruptReturn:
	%endif
	; Interrupt from user mode to kernel using a 16-bit interrupt gate
	int   0x27
	
kernelModeInterruptReturn286:
	; Interrupt from user mode to kernel conforming
	int   0x21
kernelConformingInterruptReturn:
	; Interrupt from user mode to user mode
	int   0x22
userInterruptReturn:
	call  CU_SEG_PROT32low|3:userFarFunc ; User-mode far call test
	jmp   CU_SEG_PROT32low|3:userJmpFunc ; User-mode far jump test

userFarFunc:
	retf  ; Simply return to the caller on the same privilege level

userRetfErrorFunction:
	; From user mode to kernel mode error address, which isn't allowed.
	push   C_SEG_PROT32low
	push   error
userRetfErrorLocation:
	retf
userRetfImmErrorFunction:
	; From user mode to kernel mode error address, with immediate, which isn't allowed.
	push   C_SEG_PROT32low
	push   error
userRetfImmErrorLocation:
	retf 1
userV86ExitFuncLocation:
	bits 16
	push   userV86ExitFuncRet ; Where to continue
	jmp    switchToRing0V86
	bits 32
userV86IretInterruptRet:
	bits 16
	push   dword userV86IretExitFuncLocationRet
	jmp    switchToRing0V86
	bits 32
userV86IretRealModeFunc:
	bits 16
	; Perform some pushf(d)/popf(d) with IOPL 3 test
	pushf  ; This doubles as a pushf IOPL 3 test
	popf   ; This doubles as a popf IOPL 3 test
	pushfd ; This doubles as a pushfd IOPL3 test
	popfd  ; This doubles as a popfd IOPL3 test
	pushf  ; Real pushf we need for parameters now.
	push   cs
	push   word userV86IretInterruptRet
	; Also, STI/CLI are allowed in this case, perform the test here.
	sti
	cli
	iret
	bits 32
userV86IretErrorFuncLocation:
	bits 16
	push   cs
	push   error
userV86IretErrorFuncLocationInstruction:
	iret
	jmp    error
userV86IOInstruction0:
	in     al, 0x64
	jmp    error
	bits 32

userJmpFunc:
	call   switchToRing0low ; switch back to kernel mode (ring 0)
	; CS must be C_SEG_PROT32low|0 (CPL=0)
	mov    ax, cs
	cmp    ax, C_SEG_PROT32low
	jne    error

	; Test call gates now
	jmp    testCallGateWithParameters ; Test call gate with parameters
ring0_2TestEndLocation:

	; Perform some user mode exception tests
	testUserFaultLow EX_GP, C_SEG_PROT32low, jmp C_SEG_PROT32low|3:0   ; Basic jump from user mode to kernel mode
	testUserFaultLow EX_GP, C_SEG_PROT32low, call C_SEG_PROT32low|3:0  ; Basic call from user mode to kernel mode
	testUserFaultExLow EX_GP, C_SEG_PROT32low, userRetfErrorLocation, jmp userRetfErrorFunction  ; Far return from user mode to kernel mode
	testUserFaultExLow EX_GP, C_SEG_PROT32low, userRetfImmErrorLocation, jmp userRetfImmErrorFunction  ; Far return from user mode to kernel mode

	; Test kernel mode only interrupt
	mov  eax, esp  ; Save the stack pointer for us to check, as the interrupt doesn't have a comparison.
	int  0x23
kernelModeOnlyInterruptReturn:

	; Interrupt from kernel mode to user mode is forbidden, so test for that.
	protModeFaultTestLow EX_GP, CU_SEG_PROT32low, int 0x22

	; Interrupt from kernel mode to kernel mode (conforming)
	mov  eax, esp  ; Save the stack pointer for us to check, as the interrupt doesn't have a comparison.
	int  0x24
kernelOnlyConformingInterruptReturn:

	; Test user to kernel stack switch using different address spaces
	; Interrupt from user mode to kernel mode (flat address space)
	call  switchToRing3FLATkernel ;Switch to ring 3 with flat kernel stack prepared
	int   0x26
kernelModeInterruptKernelStackReturn:
	push kernelModeInterruptKernelStackReturnPoint
	call  switchToRing0low
	kernelModeInterruptKernelStackReturnPoint:
	; Back in normal 32-bit protected mode with 16-bit segment limits again

;-------------------------------------------------------------------------------
	POST 21
;-------------------------------------------------------------------------------
;
;   Test Virtual-8086 mode
;

	; Check invalid virtual 8086 mode interrupts
	; interrupt without IOPL 3 faults with #GP(0)
	testUserV86_0_Fault EX_GP, 0, int 0x22
	; CLI/STI without IOPL 3 faults with #GP(0)
	testUserV86_0_Fault EX_GP, 0, cli
	testUserV86_0_Fault EX_GP, 0, sti
	; pushf(d) isn't allowed with IOPL 0
	testUserV86_0_Fault EX_GP, 0, pushf
	testUserV86_0_Fault EX_GP, 0, pushfd
	; popf(d) isn't allowed with IOPL 0
	testUserV86_0_Fault EX_GP, 0, popf
	testUserV86_0_Fault EX_GP, 0, popfd
	; port i/o isn't allowed with IOPL 0 and TSS I/O map set or out of range
	testUserV86_0_FaultEx EX_GP, 0, userV86IOInstruction0, call userV86IOInstruction0

	; Manipulate TSS to allow port I/O for a bit.
	push  es
	push  ebp
	les   ebp, [cs:ptrTSSprot_R2]     ; Load our TSS
	mov   word [es:ebp+0x66], 0    ; Make it available temporarily
	mov   word [es:ebp+0xC], 0     ; Make the port available
	pop   ebp
	pop   es
	call  switchToRing3V86_3       ; Switch to v86 mode to test
	bits 16
	in    al, 0x64                 ; Some valid I/O port to use that is harmless.
	push  dword V86IOSucceedFinish ; Return to kernel mode
	jmp   switchToRing0V86
	bits 32
V86IOSucceedFinish:
	push  es
	push  ebp
	les   ebp, [cs:ptrTSSprot_R2]     ; Load our TSS
	mov   word [es:ebp+0x66], 0x68 ; Make the port unavailable again
	pop   ebp
	pop   es

	; If we reach here, the return to kernel mode was successful.

	; iret without IOPL 3 faults with #GP(0)
	testUserV86_0_FaultEx EX_GP, 0, userV86IretErrorFuncLocationInstruction, call userV86IretErrorFuncLocation
	; interrupt with IOPL 3 to non-V86 privilege level 0 faults with #GP(usermodesegment)
	testUserV86_3_Fault EX_GP, CU_SEG_PROT32low, int 0x22
	; interrupt with IOPL 3 to non-V86 monitor privilege level 0 faults with #GP(kernel conforming segment)
	testUserV86_3_Fault EX_GP, CC_SEG_PROT32low, int 0x21
	; HLT is privileged and raises #GP(0) no matter what IOPL is used
	testUserV86_3_Fault EX_GP, 0, hlt
	testUserV86_0_Fault EX_GP, 0, hlt

	; iret with IOPL 3 proceeds as in real mode

	; Validate simply exiting Virtual 8086 mode, using the interrupt
	call  switchToRing3V86_3
	bits 16
	int 0x2D ;Validate we're actually in V86 mode.
	jmp   userV86IretRealModeFunc
	jmp   error
	bits 32
userV86IretExitFuncLocationRet:

	; Validate simply exiting Virtual 8086 mode, using the interrupt
	call  switchToRing3V86_3
	bits 16
	jmp   userV86ExitFuncLocation
	jmp   error
	bits 32
errorInTSS32Load:
	mov ax,DU_SEG_PROT32FLAT|3  ;SS safe value
	mov ss,ax
	mov esp,ESP_R3_PROTFLAT ;Restore our stack pointer
	jmp error               ;Error out!	

userV86ExitFuncRet:
	;Now we're going to test 16-bit interrupts in Virtual 8086 mode.
	%if ROM128
	call  switchToRing3V86_3
	BITS 16
	int 0x2E ;Verify 16-bit interrupts in Virtual 8086 mode
	userV86_16bitinterruptRET:
	push dword userV86ExitFuncRet_16bitinterrupts ; Where to continue
	jmp    switchToRing0V86
userV86ExitFuncRet_16bitinterrupts:
	%endif
	BITS 32
	pushfd
	pop eax
	and eax,0xCDFF ;Clear IOPL and interrupt flag again, as it cannot be changed in user mode
	push eax
	popfd

;Return to the high BIOS to continue testing.
	push C_SEG_PROT32
	push test386POST21end
	retf

;End of high BIOS
	;Pad to 64KB
	times 0x10000-($-$$) nop
