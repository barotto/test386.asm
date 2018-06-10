%define RMODE_SS 0x1000
%define RMODE_SP 0xffff

;
; Exception handling testing in real mode
;

; Initialises an exc handler
; %1: vector
; %2: handler IP
; Trashes AX,DS
%macro realModeExcInit 2
	mov    ax, 0
	mov    ds, ax
	mov    [%1*4], word %2
	mov    [%1*4+2], word 0xF000
	mov    ax, RMODE_SS
	mov    ss, ax
	mov    sp, RMODE_SP
%endmacro

; Checks exc result and restores the default handler
; %1: vector
; %2: expected pushed value of IP
; Trashes AX,DS
%macro realModeExcCheck 2
	cmp    sp, RMODE_SP-6
	jne    error
	cmp    [ss:RMODE_SP-4], word 0xF000
	cmp    [ss:RMODE_SP-6], word %2
	jne    error
	mov    ax, 0
	mov    ds, ax
	mov    [%1*4], word error
	mov    [%1*4+2], word 0xF000
%endmacro


; Tests a fault
; %1: vector
; %2: instruction to execute that causes a fault
%macro realModeFaultTest 2+
	realModeExcInit %1, %%continue
%%test:
	%2
	jmp    error
%%continue:
	realModeExcCheck %1, %%test
%endmacro
