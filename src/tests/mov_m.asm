;
;   Tests MOV from segment registers in real mode
;
;   %1 the segment register to test
;
%macro testMovSegR_real 1
	%if %1 = cs
	mov    dx, 0xF000
	%else
	mov    dx, 0x55AA
	%endif

	; MOV reg to Sreg
	%if %1 = cs
	realModeFaultTest 6, mov %1,dx ; test for #UD
	%else
	mov    %1, dx
	%endif

	; MOV Sreg to 16 bit reg
	xor    ax, ax
	mov    ax, %1
	cmp    ax, dx
	jne    error

	; MOV Sreg to 32 bit reg
	mov    eax, -1
	mov    eax, %1
	; bits 31:16 are undefined for Pentium and earlier processors.
	; TODO: verify on real hw and check TEST_UNDEF
	cmp    ax, dx
	jne    error

	; use ds:[0] as scratch mem, value of ds doesn't matter
	mov    bx, [0] ; save data

	; MOV Sreg to word mem
	mov    [0], word 0xbeef
	mov    [0], %1
	cmp    [0], dx
	jne    error

	; MOV word mem to Sreg
	%if %1 = cs
	realModeFaultTest 6, mov %1,[0] ; test for #UD
	%else
	mov    cx, ds ; save current DS in CX
	xor    ax, ax
	mov    %1, ax
	%if %1 = ds
	mov    es, cx
	mov    %1, [es:0]
	%else
	mov    %1, [0]
	%endif
	mov    ax, %1
	cmp    ax, dx
	jne    error
	%endif

	mov    [0], bx ; restore data

%endmacro
