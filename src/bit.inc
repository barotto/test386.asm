%macro	bitscan	1
	mov edx, 1
	shl edx, 31
	mov ecx, 31
.%1loop:
	%1  ebx, edx
	shr edx, 1
	lahf
	cmp ebx, ecx
	jne error
	sahf
	loopne .%1loop ; if CX>0 ZF must be 0
	cmp ecx, 0
	jne error ; CX must be 0
%endmacro


%macro bittest 1
	mov edx, 0xaaaaaaaa
	mov ecx, 31
.%1loop:
	%1 edx, ecx
	lahf ; save CF
	test ecx, 1
	jz .%1zero
.%1one:
	sahf ; bit in CF must be 1
	jnb error
	jmp .%1next
.%1zero:
	sahf ; bit in CF must be 0
	jb error
.%1next:
	dec ecx
	jns .%1loop
%endmacro
