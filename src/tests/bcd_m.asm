;
;	%1 op
;   %2 eax
;   %3 flags
;   %4 flags mask
;
%define quot "
%macro testBCD 4
	mov esi, %%name
	call printStr
	mov eax, %2
	call printEAX
	mov eax, %4
	push %3
	popf
	call printPS2

	mov eax, %2
	push %3
	popf
	%1
	pushfd

	jmp %%printres

%%name:
	db quot %+ %1 %+ quot,' ',0

%%printres:
	call  printEAX
	mov eax, %4
	popf
	call  printPS2
	call  printEOL
%endmacro

