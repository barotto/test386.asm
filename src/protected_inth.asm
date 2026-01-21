;
; Kernel mode interrupt handler
;
kernelInterrupt: 
	testCPL 0                  ; Elevates to CPL 0
	push  ebx
	push  ecx
	push  ds
	lds   ebx, [cs:ptrTSSprot] ; Get the TSS
	mov   ecx, [ebx+4]         ; Get TSS ESP0
	sub   ecx, 0x14+0xC        ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   error
	mov   cx, ss
	cmp   cx, word [ebx+8]     ; Did the stack pointer load correctly?
	jne   error
	pop   ds
	pop   ecx
	mov   bx, cs
	cmp   bx, C_SEG_PROT32     ; Did we end up in kernel mode correctly?
	jne   error
	pop   ebx
	cmp   dword [esp+0x00], kernelModeInterruptReturn
	jne   error                ; Invalid return address
	cmp   dword [esp+0x04], CU_SEG_PROT32|3
	jne   error                ; Invalid return code segment
	; Ignore eflags
	cmp   dword [esp+0x0C], ESP_R3_PROT
	jne   error                ; Invalid return ESP
	cmp   dword [esp+0x10], SU_SEG_PROT32|3
	jne   error                ; Invalid user stack segment
	iret                       ; Simply return to user mode


;
; Kernel mode interrupt handler
;
kernelOnlyInterrupt:
	push  ax
	testCPL 0                  ; Stays at CPL 0
	pop   ax
	push  ebx
	push  ds
	push  ecx
	lds   ebx, [cs:ptrTSSprot] ; Get the TSS
	mov   ecx, eax             ; Get ESP for the kernel mode program (stored into eax)
	sub   ecx, 0xC+0xC         ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   error
	mov   cx, ss
	mov   bx, word [bx+8]      ; Expected: kernel mode stack
	cmp   cx, bx               ; Did the stack pointer load correctly?
	jne   error
	pop   ecx
	mov   bx, cs
	cmp   bx, C_SEG_PROT32     ; Did we arrive at proper kernel code?
	jne   error
	pop   ds
	pop   ebx
	cmp   dword [esp+0x00], kernelModeOnlyInterruptReturn
	jne   error                ; Invalid return address
	cmp   dword [esp+0x04],C_SEG_PROT32
	jne   error                ; Invalid return code segment
	; Ignore eflags
	iret                       ; Simply return to kernel mode


;
; Kernel mode conforming interrupt handler
;
kernelConformingInterrupt:
	testCPL 3                 ; Conforming stays at CPL 3
	push  ebx
	push  ecx
	mov   ecx, ESP_R3_PROT    ; Get ESP for the user mode program
	sub   ecx, 0xC+0x8        ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx            ; Did the stack decrease correctly?
	jne   error
	mov   cx, ss
	mov   bx, SU_SEG_PROT32|3 ; Expected: user mode stack
	cmp   cx, bx              ; Did the stack pointer load correctly?
	jne   error
	pop   ecx
	mov   bx, cs
	cmp   bx, CC_SEG_PROT32|3 ; Did we arrive at proper conforming code?
	jne   error
	pop   ebx
	cmp   dword [esp+0x00], kernelConformingInterruptReturn
	jne   error               ; Invalid return address
	cmp   dword [esp+0x04], CU_SEG_PROT32|3
	jne   error               ; Invalid return code segment
	; Ignore eflags
	iret                      ; Simply return to user mode, stays at CPL 3


;
; Kernel mode interrupt handler
;
kernelOnlyConformingInterrupt:
	push  ax
	testCPL 0                  ; Stays at CPL 0
	pop   ax
	push  ebx
	push  ds
	push  ecx
	lds   ebx, [cs:ptrTSSprot] ; Get the TSS
	mov   ecx, eax             ; Get ESP for the kernel mode program (stored into eax)
	sub   ecx, 0xC+0xC         ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx             ; Did the stack decrease correctly?
	jne   error
	mov   cx, ss
	mov   bx, word [bx+8]      ; Expected: kernel mode stack
	cmp   cx, bx               ; Did the stack pointer load correctly?
	jne   error
	pop   ecx
	mov   bx, cs
	cmp   bx, CC_SEG_PROT32    ; Did we arrive at proper conforming kernel code?
	jne   error
	pop   ds
	pop   ebx
	cmp   dword [esp+0x00], kernelOnlyConformingInterruptReturn
	jne   error                ; Invalid return address
	cmp   dword [esp+0x04],C_SEG_PROT32
	jne   error                ; Invalid return code segment
	; Ignore eflags
	iret                       ; Simply return to kernel mode


;
; User mode interrupt handler
;
userModeInterrupt:
	testCPL 3                   ; User mode stays at CPL 3
	push  ebx
	push  ecx
	mov   ecx, ESP_R3_PROT      ; Get ESP for the user mode program
	sub   ecx, 0xC+0x8          ; Where we should end up on the kernel stack, taking into account what we just pushed
	cmp   esp, ecx              ; Did the stack decrease correctly?
	jne   error
	mov   cx, ss
	mov   bx, SU_SEG_PROT32|3   ; Expected: user mode stack
	cmp   cx, bx                ; Did the stack pointer load correctly?
	jne   error
	pop   ecx
	mov   bx, cs
	cmp   bx, CU_SEG_PROT32|3   ; Did we arrive at proper user mode code?
	jne   error
	pop   ebx
	cmp   dword [esp+0x00], userInterruptReturn
	jne   error                 ; Invalid return address
	cmp   dword [esp+0x04],CU_SEG_PROT32|3
	jne   error                 ; Invalid return code segment
	; Ignore eflags
	iret                        ; Simply return to caller, stays as user mode.


;
; Kernel mode interrupt handler, callable from user mode. Switches out of V86 mode
;
V86ModeExitInterrupt:
	call   switchedToRing0V86_cleanup ; Restore segment registers for kernel mode
	add    esp, 0x24                  ; Clean up stack from the V86 mode.
	push   eax                        ; Push the return point
	ret
