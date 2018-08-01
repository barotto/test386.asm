;
;   Output a byte to the POST port, destroys al and dx
;
%macro POST 1
	mov al, 0x%1
	mov dx, POST_PORT
	out dx, al
%endmacro

;
; Initializes an interrupt gate in system memory.
; Body of procedure used in 16 and 32-bit code segments.
;
; EAX vector
; ECX offset
; DS:EBX pointer to IDT
;
%macro initIntGateMem_body 0
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
%endmacro
