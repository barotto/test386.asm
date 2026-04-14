;
; Switches from Ring 0 to Ring 3
;
; After calling this procedure consider all the registers and flags as trashed.
; Also, the stack will be different, so saving the CPU state there will be pointless.
;
switchToRing3:
	; In order to swich to user mode (ring 3) we need to execute an IRET with these
	; values on the stack:
	; - the instruction to continue execution at - the value of EIP.
	; - the code segment selector to change to.
	; - the value of the EFLAGS register to load.
	; - the stack pointer to load.
	; - the stack segment selector to change to.
	; We also need:
	; - a 32bit code descriptor in GDT with DPL 3
	; - a 32bit data descriptor in GDT with DPL 3 (for the new stack)
	; - to put the ring 0 stack in TSS.SS0 and TSS.ESP0
	testCPL 0 ; we must be in ring 0
	pop    edx ; read the return offset
	mov    ax, ds
	lds    ebx, [cs:ptrTSSprot]
	; save ring 0 data segments, they'll be restored with switchToRing0
	mov    [ebx+0x54], ax ; save DS
	mov    ax, es
	mov    [ebx+0x48], ax ; save ES
	mov    ax, fs
	mov    [ebx+0x58], ax ; save FS
	mov    ax, gs
	mov    [ebx+0x5C], ax ; save GS
	; set ring 0 SS:ESP
	mov    [ebx+4], esp
	mov    eax, ss
	mov    [ebx+8], eax
	cli                             ; disable ints during switching
	push   dword SU_SEG_PROT32|3    ; push user stack with RPL=3
	push   dword ESP_R3_PROT        ; push user mode esp
	pushfd                          ; push eflags
	or     dword [ss:esp], 0x200    ; reenable interrupts in ring 3 (can't use privileged sti)
	push   dword CU_SEG_PROT32|3    ; push user code segment with RPL=3
	push   dword edx                ; push return EIP
	iretd

;
; Switches from Ring 0 to Ring 3, to return to ring 0 in flat mode later
;
; After calling this procedure consider all the registers and flags as trashed.
; Also, the stack will be different, so saving the CPU state there will be pointless.
;
switchToRing3FLATkernel:
	; In order to swich to user mode (ring 3) we need to execute an IRET with these
	; values on the stack:
	; - the instruction to continue execution at - the value of EIP.
	; - the code segment selector to change to.
	; - the value of the EFLAGS register to load.
	; - the stack pointer to load.
	; - the stack segment selector to change to.
	; We also need:
	; - a 32bit code descriptor in GDT with DPL 3
	; - a 32bit data descriptor in GDT with DPL 3 (for the new stack)
	; - to put the ring 0 stack in TSS.SS0 and TSS.ESP0
	testCPL 0 ; we must be in ring 0
	pop    edx ; read the return offset
	mov    ax, ds
	lds    ebx, [cs:ptrTSSprot]
	; save ring 0 data segments, they'll be restored with switchToRing0
	mov    [ebx+0x54], ax ; save DS
	mov    ax, es
	mov    [ebx+0x48], ax ; save ES
	mov    ax, fs
	mov    [ebx+0x58], ax ; save FS
	mov    ax, gs
	mov    [ebx+0x5C], ax ; save GS
	; set ring 0 SS:ESP
	mov    [ebx+4], esp
	pushfd
	or     dword [ebx+4], 0xE0010000      ; make sure we return to a proper ring0 stack
	popfd
	mov    eax, D_SEG_PROT32FLAT
	mov    [ebx+8], eax
	cli                             ; disable ints during switching
	push   dword SU_SEG_PROT32|3    ; push user stack with RPL=3
	push   dword ESP_R3_PROT        ; push user mode esp
	pushfd                          ; push eflags
	or     dword [ss:esp], 0x200    ; reenable interrupts in ring 3 (can't use privileged sti)
	push   dword CU_SEG_PROT32|3    ; push user code segment with RPL=3
	push   dword edx                ; push return EIP
	iretd

;
; Switches from Ring 0 to Ring 3 in flat mode
;
; After calling this procedure consider all the registers and flags as trashed.
; Also, the stack will be different, so saving the CPU state there will be pointless.
;
switchToRing3FLATuser:
	; In order to swich to user mode (ring 3) we need to execute an IRET with these
	; values on the stack:
	; - the instruction to continue execution at - the value of EIP.
	; - the code segment selector to change to.
	; - the value of the EFLAGS register to load.
	; - the stack pointer to load.
	; - the stack segment selector to change to.
	; We also need:
	; - a 32bit code descriptor in GDT with DPL 3
	; - a 32bit data descriptor in GDT with DPL 3 (for the new stack)
	; - to put the ring 0 stack in TSS.SS0 and TSS.ESP0
	testCPL 0 ; we must be in ring 0
	pop    edx ; read the return offset
	mov    ax, ds
	lds    ebx, [cs:ptrTSSprot]
	; save ring 0 data segments, they'll be restored with switchedToRing0FromFlat_cleanup
	mov    [ebx+0x68], ax ; save DS
	mov    ax, es
	mov    [ebx+0x6A], ax ; save ES
	mov    ax, fs
	mov    [ebx+0x6C], ax ; save FS
	mov    ax, gs
	mov    [ebx+0x6E], ax ; save GS
	; set ring 0 SS:ESP
	mov    [ebx+4], esp
	mov    eax, ss
	mov    [ebx+8], eax
	cli                             ; disable ints during switching
	push   dword DU_SEG_PROT32FLAT|3    ; push user stack with RPL=3
	push   dword ESP_R3_PROTFLAT        ; push user mode esp
	pushfd                          ; push eflags
	; don't reenable interrupts in ring 3 (can't use privileged sti) for ease of testing
	push   dword CU_SEG_PROT32FLAT|3    ; push user code segment with RPL=3
	or     edx,0xF0000              ; Fix flat instruction address
	push   dword edx                ; push return EIP
	iretd


;
; Switches from Ring 0 to Ring 3 in V86 mode
;
; After calling this procedure consider all the registers and flags as trashed.
; Also, the stack will be different, so saving the CPU state there will be pointless.
;
switchToRing3V86_0:
	; In order to swich to user mode (ring 3) we need to execute an IRET with these
	; values on the stack:
	; - the instruction to continue execution at - the value of EIP.
	; - the code segment selector to change to.
	; - the value of the EFLAGS register to load.
	; - the stack pointer to load.
	; - the stack segment selector to change to.
	; We also need:
	; - a 32bit code descriptor in GDT with DPL 3
	; - a 32bit data descriptor in GDT with DPL 3 (for the new stack)
	; - to put the ring 0 stack in TSS.SS0 and TSS.ESP0
	testCPL 0     ; we must be in ring 0
	pop    edx    ; read the return offset
	mov    ax, ds
	lds    ebx, [cs:ptrTSSprot]
	; save ring 0 data segments, they'll be restored with interrupts/exceptions
	mov    [ebx+0x54], ax ; save DS
	mov    ax, es
	mov    [ebx+0x48], ax ; save ES
	mov    ax, fs
	mov    [ebx+0x58], ax ; save FS
	mov    ax, gs
	mov    [ebx+0x5C], ax ; save GS
	; set ring 0 SS:ESP
	mov    [ebx+4], esp
	mov    eax, ss
	mov    [ebx+8], eax
	cli                             ; disable ints during switching
	push   dword V86_GS             ; V86 mode GS default to ROM
	push   dword V86_FS             ; V86 mode FS default to ROM
	push   dword V86_DS             ; V86 mode DS default to ROM
	push   dword V86_ES             ; V86 mode ES default to ROM
	push   dword 0x1000             ; push user stack with RPL=3
	push   dword ESP_R3_PROT        ; push user mode esp
	pushfd                          ; push eflags
	or     dword [ss:esp], 0x20200  ; reenable interrupts in ring 3 (can't use privileged sti), V8086 flag set, IOPL 0
	and    dword [ss:esp], 0xF0FFF  ; setup IOPL 0 properly
	push   dword 0xF000             ; push user code segment with RPL=3
	push   dword edx                ; push return EIP
	iretd


;
; Switches from Ring 0 to Ring 3 in V86 mode
;
; After calling this procedure consider all the registers and flags as trashed.
; Also, the stack will be different, so saving the CPU state there will be pointless.
;
switchToRing3V86_3:
	; In order to swich to user mode (ring 3) we need to execute an IRET with these
	; values on the stack:
	; - the instruction to continue execution at - the value of EIP.
	; - the code segment selector to change to.
	; - the value of the EFLAGS register to load.
	; - the stack pointer to load.
	; - the stack segment selector to change to.
	; We also need:
	; - a 32bit code descriptor in GDT with DPL 3
	; - a 32bit data descriptor in GDT with DPL 3 (for the new stack)
	; - to put the ring 0 stack in TSS.SS0 and TSS.ESP0
	testCPL 0     ; we must be in ring 0
	pop    edx    ; read the return offset
	mov    ax, ds
	lds    ebx, [cs:ptrTSSprot]
	; save ring 0 data segments, they'll be restored with interrupts/exceptions
	mov    [ebx+0x54], ax ; save DS
	mov    ax, es
	mov    [ebx+0x48], ax ; save ES
	mov    ax, fs
	mov    [ebx+0x58], ax ; save FS
	mov    ax, gs
	mov    [ebx+0x5C], ax ; save GS
	; set ring 0 SS:ESP
	mov    [ebx+4], esp
	mov    eax, ss
	mov    [ebx+8], eax
	cli                             ; disable ints during switching
	push   dword V86_GS             ; V86 mode GS default to ROM
	push   dword V86_FS             ; V86 mode FS default to ROM
	push   dword V86_DS             ; V86 mode DS default to ROM
	push   dword V86_ES             ; V86 mode ES default to ROM
	push   dword 0x1000             ; push user stack with RPL=3
	push   dword ESP_R3_PROT        ; push user mode esp
	pushfd                          ; push eflags
	or     dword [ss:esp], 0x23200  ; reenable interrupts in ring 3 (can't use privileged sti), V8086 flag set, IOPL 3
	push   dword 0xF000             ; push user code segment with RPL=3
	push   dword edx                ; push return EIP
	iretd


;
; Switches from Ring 3 to Ring 0 (Non-V86 mode)
;
; After calling this procedure consider all the registers and flags as trashed.
;
switchToRing0:
	testCPL 3 ; we must be in ring 3
	; In order to swich to kernel mode (ring 0) we'll use a Call Gate.
	; A placeholder for a Call Gate is already present in the GDT.
	pop    ecx ; read the return offset
	lfs    ebx, [cs:ptrGDTUprot]
	mov    eax, RING0_GATE
	mov    esi, C_SEG_PROT32
	mov    edi, .ring0
	mov    dx,  ACC_DPL_3 ; the DPL needs to be 3
	call   initCallGate
	call   RING0_GATE|3:0 ; the RPL needs to be 3, the offset will be ignored.
.ring0:
	add    esp, 16 ; remove from stack CS:EIP+SS:ESP pushed by the CALL to RING0_GATE
	; restore ring 0 data segments saved by switchToRing3
	lds    ebx, [cs:ptrTSSprot]
	mov    ax, [ebx+0x48] ; restore ES
	mov    es, ax
	mov    ax, [ebx+0x58] ; restore FS
	mov    fs, ax
	mov    ax, [ebx+0x5C] ; restore GS
	mov    gs, ax
	mov    ax, [ebx+0x54] ; restore DS
	mov    ds, ax
	; return to caller
	push   ecx
	ret

;
; Switches from Ring 3 to Ring 0 (flat user mode)
;
; After calling this procedure consider all the registers and flags as trashed.
;
switchToRing0FromFlatUser:
	testCPL 3 ; we must be in ring 3
	; In order to swich to kernel mode (ring 0) we'll use a Call Gate.
	; A placeholder for a Call Gate is already present in the GDT.
	pop    ecx ; read the return offset
	and    ecx,0xffff ;Make sure it's a 16-bit code offset.
	lfs    ebx, [cs:ptrGDTUprot+0xF0000]
	mov    eax, RING0_GATE
	mov    esi, C_SEG_PROT32
	mov    edi, .ring0_fromflatuser
	mov    dx,  ACC_DPL_3 ; the DPL needs to be 3
	call   initCallGate
	call   RING0_GATE|3:0 ; the RPL needs to be 3, the offset will be ignored.
.ring0_fromflatuser:
	add    esp, 16 ; remove from stack CS:EIP+SS:ESP pushed by the CALL to RING0_GATE
	; restore ring 0 data segments saved by switchToRing3
	; return to caller
	push   ecx
	ret


;
; Test routine for call gate with parameters
;
testCallGateWithParameters:
	push   dword switchToRing0_2 ; Where to start
	jmp    switchToRing3         ; Switch to ring 3 to start the test


;
; Switches from Ring 3 to Ring 0 (Non-V86 mode) and calls back into kernel mode with parameters
;
; After calling this procedure consider all the registers and flags as trashed.
;
switchToRing0_2:
	testCPL 3 ; we must be in ring 3
	; In order to swich to kernel mode (ring 0) we'll use a Call Gate.
	; A placeholder for a Call Gate is already present in the GDT.
	mov    ecx, ring0_2TestEndLocation   ; read the return offset
	;Setup a 32-bit call gate
	lfs    ebx, [cs:ptrGDTUprot]
	mov    eax, RING0_GATE2
	mov    esi, C_SEG_PROT32
	mov    edi, .ring0_2
	mov    dx,  ACC_DPL_3|0xA    ; the DPL needs to be 3
	call   initCallGate

	push   ecx ;Save caller

	; Create a stack of 32-bit test values to transfer using the call gate
	push   dword 0x12347654
	push   dword 0x5678CBA9
	push   dword 0x9ABC3333
	push   dword 0xDEF02222
	push   dword 0x11221111
	push   dword 0x33447777
	push   dword 0x55665555
	push   dword 0x7788AAAA
	push   dword 0x99AA4444
	push   dword 0xBBCCFFFF

	; 32-bit call gate
	call   RING0_GATE2|3:0  ; the RPL needs to be 3, the offset will be ignored.

	;Setup a 16-bit call gate
	lfs    ebx, [cs:ptrGDTUprot]
	mov    eax, RING0_GATE2
	mov    esi, C_SEG_PROT32
	mov    edi, .ring0_3
	mov    dx,  ACC_DPL_3|0xA    ; the DPL needs to be 3
	call   initCallGate286

	; Create a stack of 16-bit test values to transfer using the call gate
	push   word 0x1234
	push   word 0x5678
	push   word 0x9ABC
	push   word 0xDEF0
	push   word 0x1122
	push   word 0x3344
	push   word 0x5566
	push   word 0x7788
	push   word 0x99AA
	push   word 0xBBCC

	; 16-bit call gate
	call   RING0_GATE2|3:0  ; the RPL needs to be 3, the offset will be ignored.

	pop    ecx              ; Restore caller
	call   RING0_GATE|3:0   ; the RPL needs to be 3, the offset will be ignored.

	; This time we return to the caller proper
.ring0_2: ;32-bit call gate entry point
	push   ds
	push   ebp
	push   ebx
	lds    ebp, [cs:ptrTSSprot]
	mov    ebx, [ds:ebp+4]      ; Get the base
	sub    ebx, 0x10+0xC+40     ; Where we should end up in the kernel stack now
	cmp    esp, ebx             ; Wrong kernel stack?
	jnz    error
	mov    ebx, [ds:ebp+8]      ; Get the stack
	mov    bp, ss
	cmp    bx, bp
	jnz    error                ; Invalid kernel stack
	pop    ebx
	pop    ebp
	pop    ds
	push   eax
	mov    ax, cs
	cmp    ax, C_SEG_PROT32
	jnz    error
	pop    eax
	; Validate the parameters on the kernel stack
	cmp    [esp+0x2C], dword 0x12347654
	jne    error
	cmp    [esp+0x28], dword 0x5678CBA9
	jne    error
	cmp    [esp+0x24], dword 0x9ABC3333
	jne    error
	cmp    [esp+0x20], dword 0xDEF02222
	jne    error
	cmp    [esp+0x1C], dword 0x11221111
	jne    error
	cmp    [esp+0x18], dword 0x33447777
	jne    error
	cmp    [esp+0x14], dword 0x55665555
	jne    error
	cmp    [esp+0x10], dword 0x7788AAAA
	jne    error
	cmp    [esp+0x0C], dword 0x99AA4444
	jne    error
	cmp    [esp+0x08], dword 0xBBCCFFFF
	jne    error
	retf   40 ; Return to the user mode code, discarding the parameters from the stack.
.ring0_3: ;16-bit call gate entry point
	push   ds
	push   ebp
	push   ebx
	lds    ebp, [cs:ptrTSSprot]
	mov    ebx, [ds:ebp+4]      ; Get the base
	sub    ebx, 0x8+0xC+20     ; Where we should end up in the kernel stack now
	cmp    esp, ebx             ; Wrong kernel stack?
	jnz    error
	mov    ebx, [ds:ebp+8]      ; Get the stack
	mov    bp, ss
	cmp    bx, bp
	jnz    error                ; Invalid kernel stack
	pop    ebx
	pop    ebp
	pop    ds
	push   eax
	mov    ax, cs
	cmp    ax, C_SEG_PROT32
	jnz    error
	pop    eax
	; Validate the parameters on the kernel stack
	cmp    [esp+0x16], word 0x1234
	jne    error
	cmp    [esp+0x14], word 0x5678
	jne    error
	cmp    [esp+0x12], word 0x9ABC
	jne    error
	cmp    [esp+0x10], word 0xDEF0
	jne    error
	cmp    [esp+0x0E], word 0x1122
	jne    error
	cmp    [esp+0x0C], word 0x3344
	jne    error
	cmp    [esp+0x0A], word 0x5566
	jne    error
	cmp    [esp+0x08], word 0x7788
	jne    error
	cmp    [esp+0x06], word 0x99AA
	jne    error
	cmp    [esp+0x04], word 0xBBCC
	jne    error
	o16 retf   20 ; Return to the user mode code, discarding the parameters from the stack.



;
; Handles cleanup after returning from Ring 3 (Virtual 8086 mode) to Ring 0
;
; After calling this procedure consider all the registers and flags as trashed. Assumes that the error code has already been popped.
;
switchedToRing0V86_cleanup:
	push   ds
	push   ebx
	lds    ebx, [cs:ptrTSSprot]
	push   eax
	; restore ring 0 data segments, as they'll be restored with interrupts/exceptions calling us.
	mov    ax, [ebx+0x54]  ; restore DS
	mov    [esp+8], ax     ; Store on the stack to pop later
	mov    ax, [ebx+0x48]  ; restore ES
	mov    es, ax
	mov    ax, [ebx+0x58]  ; restore FS
	mov    fs, ax
	mov    ax, [ebx+0x5C]  ; restore GS
	mov    gs, ax
	pop    eax
	pop    ebx
	pop    ds
	ret

;
; Handles cleanup after returning from Ring 3 (Flat 32-bit mode) to Ring 0
;
; After calling this procedure consider all the registers and flags as trashed. Assumes that the error code has already been popped.
;
switchedToRing0FromFlat_cleanup:
	push   ds
	push   ebx
	lds    ebx, [cs:ptrTSSprot]
	push   eax
	; restore ring 0 data segments, as they'll be restored with interrupts/exceptions calling us.
	mov    ax, [ebx+0x68]  ; restore DS
	mov    [esp+8], ax     ; Store on the stack to pop later
	mov    ax, [ebx+0x6A]  ; restore ES
	mov    es, ax
	mov    ax, [ebx+0x6C]  ; restore FS
	mov    fs, ax
	mov    ax, [ebx+0x6E]  ; restore GS
	mov    gs, ax
	pop    eax
	pop    ebx
	pop    ds
	ret


;
; Switches from Ring 3 to Ring 0 (V86 mode). This is a jump target, not a call target.
;
; After calling this procedure consider all the registers and flags as trashed.
;
switchToRing0V86:
	bits 16
	pop    eax ; read the return offset
	int    0x25
	bits 32

