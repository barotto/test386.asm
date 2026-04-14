;
; 16-bit TSS execution path, in parallel with test386.asm tests running in 386 mode
;

ptrTSSprot32Gate: ; pointer to the 32-bit task state segment gate
	dd 0
	dw TSS_GSEG_PROT32|3

BITS 32
errorTSS16:
	mov ax,SU_SEG_PROT16SS|3              ;SS OK?
	mov ss,ax                             ;Fixup SS
	mov esp,(ESP_R3_PROT|0xFFFF0000)      ;Fixup SP
	jmp error                             ;Error out!

TSS286entrypoint:
	cmp esp,0xFFFF1122         ;SP loaded correctly?
	jnz errorTSS16
	mov esp,ESP_R3_PROT     ;Fixup SP
	cmp eax,0xFFFF1234         ;EAX loaded correctly?
	jnz errorTSS16
	cmp ecx,0xFFFF5678
	jnz errorTSS16
	cmp edx,0xFFFF9ABC
	jnz errorTSS16
	cmp ebx,0xFFFFDEF0
	jnz errorTSS16
	cmp ebp,0xFFFF3344
	jnz errorTSS16
	cmp esi,0xFFFF5566
	jnz errorTSS16
	cmp edi,0xFFFF7788
	jnz errorTSS16
	;General purpose registers are loaded OK. Now check the segment registers.
	pushfd
	pop eax
	and eax,0x4000  ;Make sure that the flags are properly tested.
	cmp eax,0x4000 ;Flags OK?
	jnz errorTSS16_1
	mov ax,ss
	cmp ax,SU_SEG_PROT16SS|3  ;SS OK?
	jnz errorTSS16_1
	mov ax,cs
	cmp ax,CU_SEG_PROT16CS|3  ;CS OK?
	jnz errorTSS16_1
	mov ax,ds
	cmp ax,SU_SEG_PROT16DS|3  ;DS OK?
	jnz errorTSS16_1
	mov ax,es
	cmp ax,SU_SEG_PROT16ES|3  ;ES OK?
	jnz errorTSS16_1
	mov ax,fs
	cmp ax,0                  ;FS OK?
	jnz errorTSS16_1
	mov ax,gs
	cmp ax,0                  ;GS OK?
	jnz errorTSS16_1
	sldt ax
	cmp ax,LDT_SEG_PROT286    ;LDT OK?
	jnz errorTSS16_1
	int 0x2B ;Validate 286 interrupts to Ring 2
	kernelModeInterruptR2Return286:
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	iret                    ;Return to the calling task
	jmp TSS1_returned
errorTSS16_1: ;Error occurred?
	jmp error
;We return here after check #1.
TSS1_returned:
	and esp,0xFFFF ;Safe ESP usage
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	;Now, we switch sides back, validating basic JMP-based task switches.
	jmp far [cs:ptrTSSprot32Gate]

	;Start of the 16-bit side of the 32-bit to 16-bit TSS tests.
	;TSS test 1: CALL busy bit set in both tasks, NT cleared to set, back-link filled by the CALL.
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT,1
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,TSS_PROT
	validateTSSNT286 TSSU_DSEG_PROT32,1,0
	validateTSSNT286 TSSU_DSEG_PROT16,0,0 ;Not written yet, so left at 0.
	validateTSSNT286 0,0,1 ;Set currently in register only.
	iretd ;Return to caller.
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT,1
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,TSS_PROT
	validateTSSNT286 TSSU_DSEG_PROT32,1,1 ;Set to 1 in source task.
	validateTSSNT286 TSSU_DSEG_PROT16,0,0 ;Left at 0.
	validateTSSNT286 0,0,1 ;Set currently in register only.
	iretd ;Return to caller.
	;Now testing JMP from 32-bit task to 16-bit task, NT in 286 task kept as-is. 16-bit task keeps it cleared.
	;TSS test 3.1: JMP busy bit set in 16-bit task, busy bit cleared in 32-bit task, NT in 286 task kept as-is, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT,0
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT32,1,1 ;Set to 1 in source task.
	validateTSSNT286 TSSU_DSEG_PROT16,0,0 ;Loaded as 0.
	validateTSSNT286 0,0,0 ;Set in destination task from the TSS.
	jmp far [cs:ptrTSSprot32Gate] ;Return to the 32-bit task.
	;TSS test 3.2 Same as before, but NT in 386 is cleared.
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT,0
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT32,1,0 ;Set to 0 in source task.
	validateTSSNT286 TSSU_DSEG_PROT16,0,1 ;Loaded as 1.
	validateTSSNT286 0,0,1 ;Set in destination task from the TSS.
	setNTflag286 0,0,1 ;Set NT flag to test.
	jmp far [cs:ptrTSSprot32Gate] ;Return to the 32-bit task.
	
	;Now, we have switched sides to check CALL from 16-bit to 32-bit.

	;Start of the 16-bit to 32-bit TSS tests.
	;Step 1: validate 16-bit TSS outgoing/incoming B-bit, NT bit, Back-link during CALL.
	;First, setup initial task state.
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	setTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	setTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	setNTflag286 0,0,0
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbusy286 TSS_PROT,0
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT32,1,0
	validateTSSNT286 TSSU_DSEG_PROT16,0,1
	validateTSSNT286 0,0,0
	call far [cs:ptrTSSprot32Gate] ;TSS test 1: CALL busy bit set in both tasks, NT cleared to set, back-link filled by the CALL. Outgoing NT kept as-is (currently 0).
	;Now, setup the second test for call, this time with NT set.
	;First, validate IRET did it's job correctly. 
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbusy286 TSS_PROT,0
	validateTSSbacklink286 TSSU_DSEG_PROT32,TSS_PROT16
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT32,1,0
	validateTSSNT286 TSSU_DSEG_PROT16,0,0
	;Reset state for detection.
	setTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	;Now, with NT bit set.
	setNTflag286 0,0,1
	call far [cs:ptrTSSprot32Gate] ;TSS test 2: CALL busy bit set in both tasks, NT set to set, back-link filled by the CALL. Outgoing NT kept as-is (currently 0).
	;Now, validate IRET did it's job correctly. 
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbusy286 TSS_PROT,0
	validateTSSbacklink286 TSSU_DSEG_PROT32,TSS_PROT16
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT32,1,0
	validateTSSNT286 TSSU_DSEG_PROT16,0,1
	;Reset state for detection.
	setTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	;Now, the 32-bit task to 16-bit task backlink is properly filled, NT properly updating for CALL and matching IRET.
	;Now, test JMP instruction task switches.
	setNTflag286 0,0,1 ;This is going to be kept in the 32-bit TSS.
	setNTflag286 TSSU_DSEG_PROT16,0,0 ;This is going to be set to 1.
	setNTflag286 TSSU_DSEG_PROT32,1,0 ;This is going to be loaded.
	jmp far [cs:ptrTSSprot32Gate] ;TSS test 3.1: JMP busy bit set in 16-bit task, busy bit cleared in 32-bit task, NT unaffected, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbusy286 TSS_PROT,0
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT16,0,1
	validateTSSNT286 TSSU_DSEG_PROT32,1,0
	validateTSSNT286 0,0,1 ;The JMP instruction to our TSS kept us.
	setNTflag286 0,0,0 ;This is going to be kept in the 16-bit TSS.
	setNTflag286 TSSU_DSEG_PROT16,0,1 ;This is going to be cleared.
	setNTflag286 TSSU_DSEG_PROT32,1,1 ;This is going to be loaded.
	jmp far [cs:ptrTSSprot32Gate] ;TSS test 3.2: JMP busy bit set in 16-bit task, busy bit cleared in 32-bit task, NT unaffected, back-link not filled by the JMP. Outgoing NT kept as-is (currently 0).
	and esp,0xFFFF ;Safe ESP usage!
	validateTSandClear 1 ;TS is expected to be set by the task switch.
	validateTSSbusy286 TSS_PROT16,1
	validateTSSbusy286 TSS_PROT,0
	validateTSSbacklink286 TSSU_DSEG_PROT32,0xDEAD
	validateTSSbacklink286 TSSU_DSEG_PROT16,0xDEAD
	validateTSSNT286 TSSU_DSEG_PROT16,0,0 ;Set to 0 in destination task.
	validateTSSNT286 TSSU_DSEG_PROT32,1,1 ;Left at 1.
	validateTSSNT286 0,0,0 ;Cleared currently in register only.

	;Finally, return to the 386 task to finish up these TSS tests and continue running other tests.
	jmp far [cs:ptrTSSprot32Gate] ;Return to the 32-bit task.

	;We've returned here to start the 386 TSS V86 mode tests.
	and esp,0xFFFF ;Safe ESP usage!
	lds ebx,[cs:ptrTSSprot_R2] ;Get the 32-bit TSS
	;Now, convert the 32-bit task to V86 mode.
	mov word [ds:ebx+0x26],0x2 ;Set the VM flag
	or word [ds:ebx+0x24],0x3000 ;Set the IOPL to 3 to allow interrupts for validation
	mov word [ds:ebx+0x48],V86_ES ;ES
	mov word [ds:ebx+0x50],S_SEG_REAL ;SS
	mov word [ds:ebx+0x54],V86_DS ;DS
	mov word [ds:ebx+0x58],V86_FS ;FS
	mov word [ds:ebx+0x5C],V86_GS ;GS
	mov word [ds:ebx+0x22],0 ;Truncate EIP to 16 bits
	mov word [ds:ebx+0x4C],0xE000 ;Code segment
	mov word [ds:ebx+0x3A],0 ;Truncate ESP to 16 bits
	
	jmp far [cs:ptrTSSprot32Gate] ;Start V86 mode!

	;We've returned from V86 mode task. Convert it back to a normal flat user mode task.
	and esp,0xFFFF ;Safe ESP usage!
	lds ebx,[cs:ptrTSSprot_R2] ;Get the 32-bit TSS
	mov word [ds:ebx+0x26],0x0 ;Clear the VM flag
	and word [ds:ebx+0x24],0xCFFF ;Set the IOPL to 0 again to restore flat user mode
	mov word [ds:ebx+0x48],SU_SEG_PROT32ES|3 ;ES
	mov word [ds:ebx+0x50],DU_SEG_PROT32FLAT|3 ;SS
	mov word [ds:ebx+0x54],SU_SEG_PROT32DS|3 ;DS
	mov word [ds:ebx+0x58],SU_SEG_PROT32FS|3 ;FS
	mov word [ds:ebx+0x5C],SU_SEG_PROT32GS|3 ;GS
	mov word [ds:ebx+0x22],0xE ;Expand EIP to 32 bits flat
	mov word [ds:ebx+0x4C],CU_SEG_PROT32FLAT|3 ;Code segment
	mov word [ds:ebx+0x3A],0x1 ;Expand ESP to 32 bits flat
	iret ;End V86 mode (we were called through an interrupt), returning to flat user mode!
	;Now, the tests have been completed.
