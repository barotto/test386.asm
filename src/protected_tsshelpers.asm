;
; 32-bit far call instructions to be called from both 286 and 386 tasks to validate the state of the current or other TSS.
;

;Define some far call pointers to execute in the proper mode no matter what TSS we're in.
ptrTSSprot32validatebusy: ; pointer to the 32-bit task state segment gate
	dd validateTSSbusy+0xE0000
	dw CU_SEG_PROT32FLAT|3

ptrTSSprot32validatebacklink: ; pointer to the 32-bit task state segment gate
	dd validateTSSbacklink+0xE0000
	dw CU_SEG_PROT32FLAT|3

ptrTSSprot32validateNT: ; pointer to the 32-bit task state segment gate
	dd validateTSSNT+0xE0000
	dw CU_SEG_PROT32FLAT|3

BITS 32

;Call below functions using a 32-bit far call.

; ValidateTSSbusy: Validate the busy bit of a TSS
; Parameters:
; EAX: lower half: TSS descriptor to validate. Bit 16=expected B-bit
validateTSSbusy:
	pushfd
	push eax
	or ax,3 ;Make sure it's in user mode
	lar ax,ax ;Load the B-bit of the TSS
	jnz LARerror
	test al,2 ;Check the B-bit
	jnz TSSisBusy
	;TSS is idle
	shr eax,0x10 ;Get the busy bit that's expected.
	jz errorTSSbusy ;If incorrect, error out
	pop eax ;Success, return.
	popfd
	retfd
LARerror:
	jmp error ;Goto error

TSSisBusy:
	shr eax,0x10 ;Get the busy bit that's expected.
	jnz errorTSSbusy ;If incorrect, error out
	pop eax ;Success, return.
	retfd

errorTSSbusy: ;Error in the TSS while checking the busy bit
	pop eax ;Restore
	jmp error

; ValidateTSSbacklink: Validate the backlink field of a TSS
; Parameters:
; EAX: lower half: TSS data descriptor to validate. upper half: expected backlink field.
validateTSSbacklink:
	pushfd
	push ds
	push eax
	or eax,3 ;Make sure we're in user mode
	mov ds,eax ;Load the TSS user-mode descriptor specified into DS
	shr eax,0x10 ;Get the expected value
	cmp ax,word [0] ;Validate the backlink field
	jnz errorTSSbacklink
	;Clean up and return.
	pop eax
	pop ds
	popfd
	retfd
errorTSSbacklink: ;An error occurred during validating the TSS backlink field?
	jmp error
	
; ValidateTSSNT: Validate the NT flag of a TSS
; Parameters:
; EAX: lower half: TSS data descriptor to check. Zeroed for current TSS (EFLAGS register). bit 16: expected NT field, bit 17: 32-bit TSS.
validateTSSNT:
	pushfd
	cmp ax,0 ;Active TSS to validate?
	jz validateCurrentTSSNT
	;Validate specified TSS
	push ds ;Save
	push eax ;Save
	push ebx ;Save
	mov ds,ax ;Load the TSS
	shr eax,2 ;Move the data to validate into bits 14(expected NT bit) and 15(32-bit TSS)
	test eax,0x8000 ;32-bit TSS?
	jnz validate32bitTSS
	mov bx,[0x10] ;Load flags register
	and ebx,0xFFFF ;Mask off unused bits
	jmp commonvalidateTSSNTbit ;Common code again
	validate32bitTSS:
	mov ebx,[0x24] ;Load eflags register
	commonvalidateTSSNTbit: ;All NT flag checks end up here. EBX is loaded with the EFLAGS register of the requested task.
	and ebx,PS_NT ;Mask off the NT bit
	and eax,PS_NT ;Mask off the NT bit
	cmp eax,ebx ;Check if the NT flag matches as we expect.
	jnz errorTSSNT ;TSS NT is containing an error
	;Clean up and return.
	pop ebx
	pop eax
	pop ds
	popfd
	retfd
errorTSSNT: ;An error occurred during validating the NT bit?
	jmp error
	
		
validateCurrentTSSNT: ;Selector 0 specified.
	push ds ;Save
	push eax ;Save
	push ebx ;Save
	mov ebx,[esp+0xC] ;Load the EFLAGS register into EBX.
	shr eax,2 ;Move the data to validate into bits 14(expected NT bit) and 15(32-bit TSS (unused))
	jmp commonvalidateTSSNTbit ;Common validation point