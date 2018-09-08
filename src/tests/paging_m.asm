;
; Tests if the CPU throws a page fault under the specified conditions.
;
; %1 PTE flags to use
; %2 expected error code value
;
; #PF error code pushed on the stack:
;
; 31                3     2     1     0
; +-----+-...-+-----+-----+-----+-----+
; |     Reserved    | U/S | W/R |  P  |
; +-----+-...-+-----+-----+-----+-----+
;
; P: When set, the fault was caused by a protection violation.
;    When not set, it was caused by a non-present page.
; W/R: When set, write access caused the fault; otherwise read access.
; U/S: When set, the fault occurred in user mode; otherwise in supervisor mode.
;
; The CR2 register contains the 32-bit linear address that caused the fault.
;
%macro testPageFault 2
	updPTEFlags TESTPAGE_PTE, %1
	xor eax, eax
	mov cr2, eax ; reset CR2 to test its value in the page faults handler
	%if (%2) & PF_USER
	call switchToRing3  ; switch to user mode
	mov ax, DU_SEG_PROT ; use user mode data segment
	%else
	mov ax, D_SEG_PROT32 ; use supervisor mode data segment
	%endif
	mov ds, ax
	mov eax, %2 ; EAX = expected error code
	%if (%2) & PF_WRITE
	; write error
	mov [TESTPAGE_OFF], dword 0xdeadbeef
	cmp eax, PF_HANDLER_SIG  ; the page fault handler should have put its signature in EAX
	jne error
	cmp [TESTPAGE_OFF], dword 0xdeadbeef
	jne error
	%else
	; read error
	mov eax, [TESTPAGE_OFF]
	cmp eax, PF_HANDLER_SIG  ; the page fault handler should have put its signature in memory
	jne error
	%endif
	%if (%2) & PF_USER
	call switchToRing0 ; switch back to supervisor mode
	%endif
	mov [TESTPAGE_OFF], dword 0 ; reset memory location used for testing
%endmacro
