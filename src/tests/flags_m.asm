;
; Tests the carry flag instructions
; Needs the stack
;
%macro testCarryFlagInstructions 0
	pushf
	;Initialize flags to cleared
	push word 0
	popf
	;Carry still set from pop?
	jc error
	cmc ;Set flag by complementing
	;Carry not complemented?
	jnc error
	cmc ;Clear flag by complementing
	;Carry not complemented?
	jc error
	stc
	;Carry not set?
	jnc error
	clc
	;Carry not cleared?
	jc error
	popf
%endmacro

;
; Tests the direction flag instructions
; Needs the stack
;
%macro testDirectionFlagInstructions 0
	pushf
	;Initialize flags to cleared
	push word 0
	popf
	pushf ;Check the flags
	pop ax
	pushf
	cmp ax,2 ;Not properly cleared?
	jnz error
	popf ;Restore our testing flags
	std ;Set the direction flag
	pushf
	pushf
	pop ax
	cmp ax,2|PS_DF ;Direction flag properly set?
	jne error
	popf ;Restore flags
	cld ;Clear the direction flag
	pushf
	pop ax
	cmp ax,2 ;Direction flag properly cleared?
	jne error
	popf
%endmacro

;
; Tests the interrupt flag instructions
; Needs the stack
;
%macro testInterruptFlagInstructions 0
	pushf
	;Initialize flags to cleared
	push word 0
	popf
	pushf ;Check the flags
	pop ax
	pushf
	cmp ax,2 ;Not properly cleared?
	jnz error
	popf ;Restore our testing flags
	sti ;Set the direction flag
	pushf
	pushf
	pop ax
	cmp ax,2|PS_IF ;Interrupt flag properly set?
	jne error
	popf ;Restore flags
	cli ;Clear the direction flag
	pushf
	pop ax
	cmp ax,2 ;Interrupt flag properly cleared?
	jne error
	popf
%endmacro

