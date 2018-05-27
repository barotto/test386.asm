;
; Tests 16-bit and 32-bit PUSH/POP for general purpose registers.
; 50+rw PUSH r16
; 50+rd PUSH r32
; 58+rw POP r16
; 58+rd POP r32
;
; %1: register to be tested, 16-bit name; one of the following:
;     ax, bx, cx, dx, bp, si, di, sp
; %2: stack address size: 16 or 32
;
%macro testPushPopR 2
	%if %1 = bp
		%define sptr eax
	%else
		%define sptr ebp
	%endif

	%if %2 = 16
		%define push16esp 0x2fffe
		%define push32esp 0x2fffc
	%else
		%define push16esp 0x1fffe
		%define push32esp 0x1fffc
	%endif

	%define r16 %1
	%define r32 e%1

	mov    esp, 0x20000          ; ESP := 0x20000
	mov    r32, 0x20000
	lea    sptr, [esp-4]         ; sptr := ESP - 4
	%if %2 = 16
	and    sptr, 0xffff          ; sptr := 0x0FFFC (sptr now mirrors SP instead of ESP)
	%endif

	mov    [sptr], dword 0xdeadbeef
	push   r32                   ; 32-bit PUSH
	cmp    [sptr], dword 0x20000 ; was the push 32-bit and did it use the correct eSP?
	jne    error                 ; no, error
	cmp    esp, push32esp        ; did the push update the correct eSP?
	jne    error                 ; no, error

	mov    [sptr], dword 0xdeadbeef
	pop    r32                   ; 32-bit POP
	cmp    r32, dword 0xdeadbeef
	jne    error

	%if r16 <> sp
	cmp    esp, 0x20000          ; did the pop update the correct eSP?
	jne    error                 ; no, error
	%endif

	mov    r32, 0x20000

	mov    [sptr], dword 0xdeadbeef
	push   r16                   ; 16-bit PUSH
	cmp    [sptr], dword 0x0000beef ; was the push 16-bit and did it use the correct eSP?
	jne    error                 ; no, error
	cmp    esp, push16esp        ; did the push update the correct eSP?
	jne    error                 ; no, error

	mov    [sptr], dword 0xdeadbeef
	pop    r16                   ; 16-bit POP
	cmp    r16, 0xdead
	jne    error

	%if r16 <> sp
	cmp    esp, 0x20000          ; did the pop update the correct eSP?
	jne    error                 ; no, error
	%endif
%endmacro

