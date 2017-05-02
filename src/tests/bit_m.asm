%macro testBitscan 1
	mov edx, 1
	shl edx, 31
	mov ecx, 31
%%loop32:
	o32 %1  ebx, edx
	shr edx, 1
	lahf
	cmp ebx, ecx
	jne error
	sahf
	loopne %%loop32 ; if CX>0 ZF must be 0
	cmp ecx, 0
	jne error ; CX must be 0

	mov dx, 1
	shl dx, 15
	mov cx, 15
%%loop16:
	o16 %1  bx, dx
	shr dx, 1
	lahf
	cmp bx, cx
	jne error
	sahf
	loopne %%loop16 ; if CX>0 ZF must be 0
	cmp cx, 0
	jne error ; CX must be 0
%endmacro


%macro testBittest16 1
	mov edx, 0x0000aaaa
	mov cx, 15
%%loop:
	o16 %1 dx, cx
	lahf ; save CF
	test cx, 1
	jz %%zero
%%one:
	sahf ; bit in CF must be 1
	jnb error
	jmp %%next
%%zero:
	sahf ; bit in CF must be 0
	jb error
%%next:
	dec cx
	jns %%loop
%endmacro

%macro testBittest32 1
	mov edx, 0xaaaaaaaa
	mov ecx, 31
%%loop:
	o32 %1 edx, ecx
	lahf ; save CF
	test ecx, 1
	jz %%zero
%%one:
	sahf ; bit in CF must be 1
	jnb error
	jmp %%next
%%zero:
	sahf ; bit in CF must be 0
	jb error
%%next:
	dec ecx
	jns %%loop
%endmacro
