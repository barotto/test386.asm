;
; 32-bit far call instructions to be called from both 286 and 386 tasks to validate the state of the current or other TSS.
;

;Define some far call pointers to execute in the proper mode no matter what TSS we're in.
ptrTSSprot32validatebusy: ; pointer to the 32-bit task state segment function
	dd validateTSSbusy+0xE0000
	dw CU_SEG_PROT32FLAT|3

ptrTSSprot32validatebacklink: ; pointer to the 32-bit task state segment function
	dd validateTSSbacklink+0xE0000
	dw CU_SEG_PROT32FLAT|3

ptrTSSprot32setbacklink: ; pointer to the 32-bit task state segment function
	dd setTSSbacklink+0xE0000
	dw CU_SEG_PROT32FLAT|3

ptrTSSprot32validateNT: ; pointer to the 32-bit task state segment function
	dd validateTSSNT+0xE0000
	dw CU_SEG_PROT32FLAT|3

ptrTSSprot32setNT: ; pointer to the 32-bit task state segment function
	dd setTSSNT+0xE0000
	dw CU_SEG_PROT32FLAT|3

TSShelpererrorptr: ;An error occurred while validating task state segment information
	dd error
	dw CU_SEG_PROT32

BITS 32

;Call below functions using a 32-bit far call.

; ValidateTSSbusy: Validate the busy bit of a TSS
; Parameters:
; EAX: lower half: TSS descriptor to validate. Bit 16=expected B-bit
validateTSSbusy:
	pushfd
	push eax
	push ebx
	mov ebx,eax ;Copy of the bit
	or ax,3 ;Make sure it's in user mode
	lar ax,ax ;Load the B-bit of the TSS
	jnz errorTSSbusy ;Error executing LAR
	;TSS is idle
	shr ebx,7 ;Get the busy bit that's expected to match positions.
	and ah,2 ;Get the bit to inspect
	and bh,2 ;Get the bit to inspect
	cmp ah,bh ;Compare the bits to their expected results
	jnz errorTSSbusy ;If incorrect, error out
	pop ebx
	pop eax ;Success, return.
	popfd
	retfd
errorTSSbusy: ;Error in the TSS while checking the expected busy bit
	pop ebx ;Restore
	pop eax
	popfd
	jmp far [cs:TSShelpererrorptr+0xE0000]

; validateTSSbacklink: Validate the backlink field of a TSS
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
	jmp far [cs:TSShelpererrorptr+0xE0000]
	
; setTSSbacklink: Clear the backlink field of a TSS
; Parameters:
; EAX: lower half: TSS data descriptor to validate. upper half: expected backlink field.
setTSSbacklink:
	pushfd
	push ds
	push eax
	or eax,3 ;Make sure we're in user mode
	mov ds,eax ;Load the TSS user-mode descriptor specified into DS
	shr eax,0x10 ;Get the value to set.
	mov word [0], ax ;Set the backlink field
	;Clean up and return.
	pop eax
	pop ds
	popfd
	retfd

; validateTSSNT: Validate the NT flag of a TSS
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
	jmp far [cs:TSShelpererrorptr+0xE0000]
	
		
validateCurrentTSSNT: ;Selector 0 specified.
	push ds ;Save
	push eax ;Save
	push ebx ;Save
	mov ebx,[esp+0xC] ;Load the EFLAGS register into EBX.
	shr eax,2 ;Move the data to validate into bits 14(expected NT bit) and 15(32-bit TSS (unused))
	jmp commonvalidateTSSNTbit ;Common validation point

; setTSSNT: Set the NT flag of a TSS
; Parameters:
; EAX: lower half: TSS data descriptor to check. Zeroed for current TSS (EFLAGS register). bit 16: NT to set, bit 17: 32-bit TSS.
setTSSNT:
	push ecx ;Type determination
	pushfd
	cmp ax,0 ;Active TSS to validate?
	jz setCurrentTSSNT
	mov ecx,0 ;Default: type TSS.
	;Validate specified TSS
	push ds ;Save
	push eax ;Save
	push ebx ;Save
	push edx ;Save
	mov ds,ax ;Load the TSS
	shr eax,2 ;Move the data to validate into bits 14(expected NT bit) and 15(32-bit TSS)
	mov edx,eax ;Backup
	test eax,0x8000 ;32-bit TSS?
	jnz get32bitTSSNT
	mov bx,[0x10] ;Load flags register
	and ebx,0xFFFF ;Mask off unused bits
	jmp commonsetTSSNTbit ;Common code again
	get32bitTSSNT:
	mov ebx,[0x24] ;Load eflags register
	commonsetTSSNTbit: ;All NT flag checks end up here. EBX is loaded with the EFLAGS register of the requested task.
	and bx,0xBFFF ;Mask off the NT bit
	and eax,PS_NT ;Mask off the NT bit
	or bx,ax ;Set the NT bit only.
	cmp ecx,0 ;Type TSS?
	jnz finishTSSsetEFLAGS
	;Type TSS.
	test edx,0x8000 ;32-bit TSS?
	jnz set32bitsTSSNT
	;16-bit TSS to write.
	mov [0x10], bx ;Set the FLAGS register.
	jmp commonfinishTSSsetNTbit
	set32bitsTSSNT:
	;32-bits TSS to write.
	mov [0x24], bx ;Set the FLAGS register.
	commonfinishTSSsetNTbit:
	;Clean up and return.
	pop edx
	pop ebx
	pop eax
	pop ds
	popfd
	pop ecx
	retfd
finishTSSsetEFLAGS:
	mov [esp+0x10], bx ;Update on the stack instead.
	jmp commonfinishTSSsetNTbit
		
setCurrentTSSNT: ;Selector 0 specified.
	mov ecx,1 ;Type is requested to be EFLAGS instead.
	push ds ;Save
	push eax ;Save
	push ebx ;Save
	push edx ;Save
	mov ebx,[esp+0x10] ;Load the EFLAGS register into EBX.
	shr eax,2 ;Move the data to validate into bits 14(expected NT bit) and 15(32-bit TSS (unused))
	mov edx,eax ;Backup
	jmp commonsetTSSNTbit ;Common validation point

