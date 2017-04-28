;
;   Test store, move, scan, and compare string data
;   %1 b,w,d
;   %2 0,1,2
;   DS:ESI test buffer 1
;   ES:EDI test buffer 2
;   ECX: buffer size in byte/words/dwords
;
%macro testStringOps 2
	mov    ebp, ecx   ; EBP <- buffers dword size (can't use stack to save)
	mov    ebx, ecx
	shl    ebx, %2     ; EBX <- buffers byte size

	mov    eax, 0x12345678
	cld

	; STORE buffers with pattern in EAX
	rep stos%1           ; store ECX dwords at ES:EDI from EAX
	cmp    ecx, 0
	jnz    error        ; ECX must be 0
	sub    edi, ebx     ; rewind EDI
	; now switch ES:EDI with DS:ESI
	mov    dx, es
	mov    cx, ds
	xchg   dx, cx
	mov    es, dx
	mov    ds, cx
	xchg   edi, esi
	; store again ES:EDI with pattern in EAX
	mov    ecx, ebp     ; reset ECX
	rep stos%1
	sub    edi, ebx     ; rewind EDI

	; COMPARE two buffers
	mov    ecx, ebp     ; reset ECX
	repe cmps%1          ; find nonmatching dwords in ES:EDI and DS:ESI
	cmp    ecx, 0
	jnz    error        ; ECX must be 0
	sub    edi, ebx     ; rewind EDI
	sub    esi, ebx     ; rewind ESI

	; SCAN buffer for pattern
	mov    ecx, ebp     ; reset ECX
	repe scas%1          ; SCAN first dword not equal to EAX
	cmp    ecx, 0
	jne    error        ; ECX must be 0
	sub    edi, ebx     ; rewind EDI

	; MOVE and COMPARE data between buffers
	; first zero-fill ES:EDI so that we can compare the moved data later
	mov    eax, 0
	mov    ecx, ebp     ; reset ECX
	rep stos%1           ; zero fill ES:EDI
	sub    edi, ebx     ; rewind EDI
	mov    ecx, ebp     ; reset ECX
	rep movs%1           ; MOVE data from DS:ESI to ES:EDI
	sub    edi, ebx     ; rewind EDI
	sub    esi, ebx     ; rewind ESI
	repe cmps%1          ; COMPARE moved data in ES:EDI with DS:ESI
	cmp    ecx, 0
	jne    error        ; ECX must be 0
%endmacro
