;
;   Tests MOV to and from segment registers
;   %1 the segment register to test
;   Uses: EAX, EDX, Flags, the tested segreg
;
%macro testMovSegR 1
	mov    edx, 0x5555
	mov    %1, dx
	mov    ax, %1
	cmp    ax, dx
	jne    error
	mov    eax, %1
	cmp    eax, edx
	jne    error
%endmacro
