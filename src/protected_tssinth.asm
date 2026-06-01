BITS 32

ptrTSSprot_R2: ; pointer to the task state segment
	dd 0
	dw TSSU_DSEG_PROT32|3
ptrTSSprot_R0: ; pointer to the task state segment
	dd 0
	dw TSS_DSEG_PROT
ptrTSSprot16_R2: ; pointer to the 16-bit task state segment
	dd 0
	dw TSSU_DSEG_PROT16|3
ptrTSSerrorR0_2: ; pointer to the error condition, from ring 0 or ring 2
	dd error
	dw CU_SEG_PROT32|3
ptrGDTUprot_R2: ; pointer to the GDT for pmode (user mode data segment)
	dd 0
	dw GDTU_DSEG_PROT|3	
ptrIDTprot_R0: ; pointer to the IDT for pmode
	dd 0             ; 32-bit offset
	dw IDT_SEG_PROT  ; 16-bit segment selector
ptrIDTUprot_R3: ; pointer to the IDT for pmode
	dd 0             ; 32-bit offset
	dw IDTU_SEG_PROT  ; 16-bit segment selector
ptrSSprot_R0: ; pointer to the stack for pmode
	dd ESP_R0_PROT
	dw S_SEG_PROT32
errorCPLn:
	jmp far [cs:ptrTSSerrorR0_2] ;JMP to the error condition.

;
; Kernel mode interrupt handler
;
kernelInterrupt: 
	testCPL 0                  ; Elevates to CPL 0
	push  ebx
	push  ecx
	push  ds
	lds   ebx, [cs:ptrTSSprot_R2] ; Get the TSS
	mov   ecx, [ebx+4]         ; Get TSS ESP0
	sub   ecx, 0x14+0xC        ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   errorCPLn
	mov   cx, ss
	cmp   cx, word [ebx+8]     ; Did the stack pointer load correctly?
	jne   errorCPLn
	pop   ds
	pop   ecx
	mov   bx, cs
	cmp   bx, C_SEG_PROT16CS     ; Did we end up in kernel mode correctly?
	jne   errorCPLn
	pop   ebx
	cmp   dword [esp+0x00], kernelModeInterruptReturn
	jne   errorCPLn                ; Invalid return address
	cmp   dword [esp+0x04], CU_SEG_PROT32low|3
	jne   errorCPLn                ; Invalid return code segment
	; Ignore most eflags
	test  dword [esp+0x08], PS_IF ;EFLAGS input
	jz    errorCPLn
	cmp   dword [esp+0x0C], ESP_R3_PROT
	jne   errorCPLn                ; Invalid return ESP
	cmp   dword [esp+0x10], SU_SEG_PROT32|3
	jne   errorCPLn                ; Invalid user stack segment
	push  eax
	pushfd
	pop eax
	test eax, PS_IF ;Incorrect flags.
	jnz   errorCPLn
	pop   eax
	iret                       ; Simply return to user mode

;
; Kernel mode interrupt handler (ring 2) for 32-bit TSS
;
kernelInterrupt_R2_386: 
	testCPL_E 2,errorCPLn          ; Elevates to CPL 2
	push  ebx
	push  ecx
	push  ds
	lds   ebx, [cs:ptrTSSprot_R2] ; Get the TSS
	mov   ecx, [ebx+0x14]         ; Get TSS ESP2
	sub   ecx, 0x14+0xC        ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   errorCPLn
	mov   cx, ss
	push  edx
	mov   dx, word [ebx+0x18]
	or    dx, 2      ;Privilege level 2
	cmp   cx, dx     ; Did the stack pointer load correctly?
	pop   edx
	jne   errorCPLn
	pop   ds
	pop   ecx
	mov   bx, cs
	cmp   bx, C_SEG_PROT32_R2|2     ; Did we end up in kernel mode correctly?
	jne   errorCPLn
	pop   ebx
	push  ebx
	mov   ebx, kernelModeInterruptR2Return
	or    ebx, 0xE0000
	cmp   dword [esp+0x04], ebx
	pop   ebx
	jne   errorCPLn                ; Invalid return address
	cmp   dword [esp+0x04], CU_SEG_PROT32FLAT|3
	jne   errorCPLn                ; Invalid return code segment
	; Ignore eflags
	cmp   dword [esp+0x0C], ESP_R3_PROTFLAT
	jne   errorCPLn                ; Invalid return ESP
	cmp   dword [esp+0x10], DU_SEG_PROT32FLAT|3
	jne   errorCPLn                ; Invalid user stack segment
	iret                       ; Simply return to user mode

;
; Kernel mode interrupt handler (ring 2) for 16-bit TSS
;
kernelInterrupt_R2_286: 
	testCPL_E 2,errorCPLn          ; Elevates to CPL 2
	push  ebx
	push  ecx
	push  ds
	lds   ebx, [cs:ptrTSSprot16_R2] ; Get the TSS
	mov   cx, [ebx+0xA]         ; Get TSS ESP2
	and   ecx,0xFFFF
	sub   ecx, 0x14+0xC        ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   errorCPLn
	mov   cx, ss
	push  edx
	mov   dx, word [ebx+0xC]
	or    dx, 2      ;Privilege level 2
	cmp   cx, dx     ; Did the stack pointer load correctly?
	pop   edx
	jne   errorCPLn
	pop   ds
	pop   ecx
	mov   bx, cs
	cmp   bx, C_SEG_PROT32_R2|2     ; Did we end up in kernel mode correctly?
	jne   errorCPLn
	pop   ebx
	cmp   dword [esp+0x00], kernelModeInterruptR2Return286
	jne   errorCPLn                ; Invalid return address
	cmp   dword [esp+0x04], CU_SEG_PROT16CS|3
	jne   errorCPLn                ; Invalid return code segment
	; Ignore eflags
	cmp   dword [esp+0x0C], ESP_R3_PROT
	jne   errorCPLn                ; Invalid return ESP
	cmp   dword [esp+0x10], SU_SEG_PROT16SS|3
	jne   errorCPLn                ; Invalid user stack segment
	iret                       ; Simply return to user mode

;
; Kernel mode interrupt handler to validate a 32-bit TSS
;
kernelInterrupt_validateAndClearTS: 
	testCPL_E 0,errorCPLn           ; Elevates to CPL 0
	push eax
	push ebx
	smsw eax ;Load CR0, alternative way
	mov ebx, cr0 ;Load CR0, normal way
	cmp ebx, eax ;CR0 loaded correctly?
	jne errorCPLn ;Error out if not.
	mov eax, [esp+4] ;Requested EAX restored.
	shl eax, 3 ;Move tested bit to bit 3 (TS)
	and eax, 0x08 ;Bit to test
	and ebx, 0x08 ;Bit to test
	cmp ebx, eax ;As expected?
	jne errorCPLn ;Invalid TS bit
	clts ;Clear the TS bit
	smsw ebx ;Load CR0
	and ebx,0x08 ;Bit to test
	jnz errorCPLn ;TS bit not properly cleared?
	pop ebx
	pop eax
	iret                       ; Simply return to user mode

;
; Kernel mode interrupt handler, callable from user mode. Validates if the Virtual 8086 mode is used.
;
kernelInterrupt_validateV86mode16bit:
	;Validate the PL0 stack is loaded correctly.
	push  ax
	testCPL_E 0,errorCPLn                  ; Elevates to CPL 0
	pop   ax
	push  ebx
	push  ds
	push  ecx
	lds   ebx, [cs:ptrTSSprot_R2] ; Get the TSS
	mov   ecx, dword [bx+4]             ; Get ESP for the kernel mode program (stored into eax)
	sub   ecx, 0xC+0x12         ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   errorCPLn
	mov   cx, ss
	mov   bx, word [bx+8]      ; Expected: kernel mode stack
	cmp   cx, bx               ; Did the stack pointer load correctly?
	jne   errorCPLn
	pop   ecx
	mov   bx, cs
	cmp   bx, C_SEG_PROT16CS     ; Did we arrive at proper kernel code?
	jne   errorCPLn
	pop   ds
	pop   ebx
	;Basic stack pointer verified. Now check if the data on the stack is correct, while building a new stack to return to user mode.
	;Now, we need to convert the 16-bit PL0 stack into a 32-bit one for IRET to succeed.
	push eax ;Save our original AX register
	and eax,0xFFFF ;Mask off upper 16 bits.
	mov ax, word [esp+(0x04+0x10)] ;GS
	cmp ax,V86_GS                  ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination GS
	mov ax, word [esp+(0x08+0x0E)] ;FS
	cmp ax,V86_FS                  ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination FS
	mov ax, word [esp+(0x0C+0x0C)] ;DS
	cmp ax,V86_DS                  ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination DS
	mov ax, word [esp+(0x10+0x0A)] ;ES
	cmp ax,V86_ES                  ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination ES
	mov ax, word [esp+(0x14+0x08)] ;SS
	cmp ax,0x1000                  ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination SS
	mov ax, word [esp+(0x18+0x06)] ;SP
	cmp ax,ESP_R3_PROT             ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination ESP
	mov ax, word [esp+(0x1C+0x04)] ;FLAGS
	push eax ;Save destination EFLAGS
	mov ax, word [esp+(0x20+0x02)] ;CS
	cmp ax,0xE000                  ;Correct?
	jne errorCPLn                  ;Error if incorrect.
	push eax ;Save destination CS
	mov ax, word [esp+(0x24+0x00)] ;IP
	cmp ax,userV86_16bitinterruptRET ;IP correct?
	jne errorCPLn ;Incorrect IP address.
	push eax ;Save destination EIP
	or dword [esp+0x08],0x20000 ;Set VM bit to properly return.
	mov eax,[esp+0x2C] ;Load original EAX register to restore it.
	iret
;
; Kernel mode interrupt handler, callable from user mode. Validates if the Virtual 8086 mode is used.
;
BITS 16
realmodeError:
	push word 0xF000
	push word error
	retf
realmodeInterrupt:
	push  ebx
	push  ecx
	mov   ecx, eax                   ; Get ESP for the interrupt program (stored into eax)
	sub   ecx, 0x6+0x8               ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   sp, cx                     ; Did the stack decrease correctly?
	jne   realmodeError
	pop   ecx
	mov   bx, cs
	cmp   bx, 0xE000                 ; Did we arrive at proper kernel code?
	jne   realmodeError
	;Basic stack pointer verified. Now check if the data on the stack is correct, while building a new stack to return to real mode.
	;Ignore most flags
	test word [esp+(0x4+0x04)],PS_IF ;EFLAGS input
	jz    realmodeError
	and   esp,0xFFFF ;Real mode safety.
	mov   bx, word [esp+(0x4+0x02)]  ;CS
	cmp   bx,0xE000                  ;Correct?
	jne   error                      ;Error if incorrect.
	mov   bx, word [esp+0x4] ;IP
	cmp   bx,realmodeInterruptRET    ;IP correct?
	jne   realmodeError              ;Incorrect IP address.
	pushfd
	pop   eax
	test  eax,PS_IF                  ;Incorrect flags.
	jnz   realmodeError 
	pop   ebx
	iret
BITS 32