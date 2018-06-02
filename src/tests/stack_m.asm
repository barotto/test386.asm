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

;
; Tests 16-bit and 32-bit PUSH/POP for segment registers.
;   0E PUSH CS
;   1E PUSH DS
;   1F POP DS
;   16 PUSH SS
;   17 POP SS
;   06 PUSH ES
;   07 POP ES
; 0FA0 PUSH FS
; 0FA1 POP FS
; 0FA8 PUSH GS
; 0FA9 POP GS
;
; %1: register to be tested, one of the following:
;     cs, ds, ss, es, fs, gs
; %2: stack address size: 16 or 32
;
%macro testPushPopSR 2
	%if %2 = 16
		%define push16esp 0x2fffe
		%define push32esp 0x2fffc
	%else
		%define push16esp 0x1fffe
		%define push32esp 0x1fffc
	%endif

	mov    dx, %1                ; save segment register value
	mov    esp, 0x20000
	lea    ebp, [esp-4]
	%if %2 = 16
	and    ebp, 0xffff           ; EBP now mirrors SP instead of ESP
	%endif

	mov    [ebp], dword 0xdeadbeef ; put control dword on stack
	o32 push %1                  ; 32-bit PUSH
	cmp    [ebp], dx             ; was the least significant word correctly written?
	jne    error                 ; no, error
	%if TEST_UNDEF
	; 80386, 80486 perform a 16-bit move, leaving the upper portion of the stack
	; location unmodified (tested on real hardware). Probably all 32-bit Intel
	; CPUs behave in this way, but this behaviour is not specified in the docs
	; for older CPUs and is cited in the most recent docs like this:
	; "If the source operand is a segment register (16 bits) and the operand
	; size is 32-bits, either a zero-extended value is pushed on the stack or
	; the segment selector is written on the stack using a 16-bit move. For the
	; last case, all recent Core and Atom processors perform a 16-bit move,
	; leaving the upper portion of the stack location unmodified."
	cmp    [ebp+2], word 0xdead  ; has the most significant word been overwritten?
	jne    error                 ; yes, error
	%endif
	cmp    esp, push32esp        ; did the push update the correct stack pointer reg?
	jne    error                 ; no, error

	%if %1 <> cs
	mov    [ebp], dword DSEG_PROT16B ; write test segment on stack
	o32 pop %1                   ; 32-bit POP
	mov    ax, %1
	cmp    ax, DSEG_PROT16B      ; is the popped segment the one on the stack?
	jne    error                 ; no, error
	cmp    esp, 0x20000          ; did the pop update the correct stack pointer reg?
	jne    error                 ; no, error
	mov    %1, dx                ; restore segment
	%else
	mov    esp, 0x20000
	%endif

	mov    [ebp], dword 0xdeadbeef
	o16 push %1                  ; 16-bit PUSH
	cmp    [ebp+2], dx           ; was the push 16-bit and did it use the correct stack pointer reg?
	jne    error                 ; no, error
	cmp    esp, push16esp        ; did the push update the correct stack pointer reg?
	jne    error                 ; no, error

	%if %1 <> cs
	mov    [ebp+2], word DSEG_PROT16B ; write test segment on stack
	o16 pop %1                   ; 16-bit POP
	mov    ax, %1
	cmp    ax, DSEG_PROT16B      ; is the popped segment the one on the stack?
	jne    error                 ; no, error
	cmp    esp, 0x20000          ; did the pop update the correct stack pointer reg?
	jne    error                 ; no, error
	mov    %1, dx                ; restore segment
	%else
	mov esp, 0x20000
	%endif

%endmacro

;
; Tests 16-bit and 32-bit PUSH/POP with memory operand.
; FF /6 PUSH r/m16
; FF /6 PUSH r/m32
; 8F /0 POP r/m16
; 8F /0 POP r/m32
;
; %1: stack address size: 16 or 32
;
%macro testPushPopM 1

	%if %1 = 16
		%define push16esp 0x2fffe
		%define push32esp 0x2fffc
	%else
		%define push16esp 0x1fffe
		%define push32esp 0x1fffc
	%endif

	mov    esp, 0x20000
	lea    ebp, [esp-4]
	%if %1 = 16
	and    ebp, 0xffff             ; EBP now mirrors SP instead of ESP
	%endif

	lea    esi, [esp-8]            ; init pointer to dword operand in memory
	mov    [esi], dword 0x11223344 ; put test dword in memory

	mov    [ebp], dword 0xdeadbeef ; put control dword on stack
	push   dword [esi]             ; 32-bit PUSH
	cmp    [ebp], dword 0x11223344 ; was it a 32-bit push? did it use the correct pointer?
	jne    error                   ; no, error
	cmp    esp, push32esp          ; did the push update the correct stack pointer reg?
	jne    error                   ; no, error

	mov    [esi], dword 0xdeadbeef ; put control dword in memory
	pop    dword [esi]             ; 32-bit POP
	cmp    [esi], dword 0x11223344 ; was it a 32-bit pop? did it use the correct pointer?
	jne    error                   ; no, error
	cmp    esp, 0x20000            ; did the pop update the correct eSP?
	jne    error                   ; no, error

	mov    [ebp], dword 0xdeadbeef ; put control dword on stack
	push   word [esi]              ; 16-bit PUSH
	cmp    [ebp], dword 0x3344beef ; was it a 16-bit push? did it use the correct pointer?
	jne    error                   ; no, error
	cmp    esp, push16esp          ; did the push update the correct pointer?
	jne    error                   ; no, error

	mov    [esi], dword 0xdeadbeef ; put control dword in memory
	pop    word [esi]              ; 16-bit POP
	cmp    [esi], dword 0xdead3344 ; was it a 16-bit pop? did it use the correct pointer?
	jne    error                   ; no, error
	cmp    esp, 0x20000            ; did the pop update the correct pointer?
	jne    error                   ; no, error
%endmacro
