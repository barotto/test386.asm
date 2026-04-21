;
; Tests GDT/IDT loading and saving.
; Uses: EAX, EBX, ECX, EDX, Flags
;

; testDTRpattern
; Parameters:
; %1: 0 for 16-bit load, 1 for 32-bit load
; %2: load instruction
; %3: save instruction
; %4: value to load (base)
; %5: value to load (limit)
; %6: error jump
%macro testDTRpattern 6
	;Load input
	mov dword [0],%5
	mov dword [2],%4
	;Initialize expected output storage
	mov dword [8],0xDEADDEAD
	mov dword [0xC],0xDEADDEAD
	mov ebx,dword [2]
	%if %1==0
	;16-bits load clears the top byte
	and ebx,0xFFFFFF
	%endif
	mov ecx,[4]
	%if %1==1
	;Load it
	o32 %2 [0]
	%else
	;Load it
	o16 %2 [0]
	%endif
	;Save the result (full 32-bit)
	o32 %3 [8]
	;Load base calculated
	mov eax,dword [0xA]
	; Compare 32-bits
	cmp eax,ebx
	jne %6
	;Load the limit that was loaded/stored.
	mov ax,word [0x8]
	;Only 16 bits stored.
	cmp ax,%5
	jne %6
	mov dword [8],0xDEADDEAD
	mov dword [0xC],0xDEADDEAD

	;Save the result (full 16-bit version). Undocumented: it stores the upper 8 bits too, just like with the 32-bits version.
	o16 %3 [8]
	;Load base calculated
	mov eax,dword [0xA]
	; Compare 32-bits
	cmp eax,ebx
	jne %6
	;Load the limit that was loaded/stored.
	mov ax,word [0x8]
	;Only 16 bits stored.
	cmp ax,%5
	jne %6
%endmacro

; testDTR
; Parameters:
; %1: 0 for 16-bit load, 1 for 32-bit load
; %2: load instruction
; %3: save instruction

%macro testDTR 3
	jmp %%skiperror
%%error:
	push word 0xF000
	push word error
	retf
%%skiperror:
	testDTRpattern %1,%2,%3,0,0,%%error
	testDTRpattern %1,%2,%3,0x12345678,0xAABB,%%error
	testDTRpattern %1,%2,%3,0xCCDDEEFF,0x1122,%%error
	testDTRpattern %1,%2,%3,0xFFFFFFFF,0xEEEE,%%error
	;Cleanup: Restore real mode tables.
	mov [0],0
	mov [4],0x3FF
	o16 lidt [0]
	mov [4],0xFFFF
	o16 lgdt [0]
%endmacro
