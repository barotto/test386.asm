;
; Initializes an interrupt gate in system memory
;
; EAX vector
; ECX offset
; DS:EBX pointer to IDT
;
initIntGateMem:
	pushad
	pushf
	shl    eax, 3
	add    ebx, eax
	mov    word [ebx], cx
	mov    dx, CSEG_PROT32
	mov    word [ebx+2], dx
	mov    word [ebx+4], ACC_TYPE_GATE386_INT | ACC_PRESENT
	shr    ecx, 16
	mov    word [ebx+6], cx
	popf
	popad
	ret


