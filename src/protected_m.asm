;
;   Defines an interrupt gate, given a selector (%1) and an offset (%2)
;
%macro defIntGate 2
	dw    (%2 & 0xffff)
	dw    %1
	dw    ACC_TYPE_GATE386_INT | ACC_PRESENT
	dw    (%2 >> 16) & 0xffff
%endmacro

;
;   Defines a descriptor, given a name (%1), base (%2), limit (%3), type (%4), and ext (%5)
;
%assign selDesc 0

%macro defDesc 1-5 0,0,0,0
	%assign %1 selDesc
	dw (%3 & 0x0000ffff)
	dw (%2 & 0x0000ffff)
	%if selDesc = 0
	dw ((%2 & 0x00ff0000) >> 16) | %4 | (0 << 13)
	%else
	dw ((%2 & 0x00ff0000) >> 16) | %4 | (0 << 13) | ACC_PRESENT
	%endif
	dw ((%3 & 0x000f0000) >> 16) | %5 | ((%2 & 0xff000000) >> 16)
	%assign selDesc selDesc+8
%endmacro

;
; Initializes an interrupt gate in system memory
; %1 vector
; %2 offset
; DS:EBX pointer to IDT
;
%macro protModeExcInit 2
	mov    eax, %1
	mov    ecx, %2
	call   initIntGateMem
%endmacro

;
; Initializes the protected mode IDT in memory
;
; This macro executes in real mode.
;
%macro initProtModeIDT 0
	lds    ebx, [cs:memIDTptrReal]

	protModeExcInit  0, OFF_INTDIVERR
	protModeExcInit  1, OFF_INTDEFAULT
	protModeExcInit  2, OFF_INTDEFAULT
	protModeExcInit  3, OFF_INTDEFAULT
	protModeExcInit  4, OFF_INTDEFAULT
	protModeExcInit  5, OFF_INTBOUND
	protModeExcInit  6, OFF_INTDEFAULT
	protModeExcInit  7, OFF_INTDEFAULT
	protModeExcInit  8, OFF_INTDEFAULT
	protModeExcInit  9, OFF_INTDEFAULT
	protModeExcInit 10, OFF_INTDEFAULT
	protModeExcInit 11, OFF_INTDEFAULT
	protModeExcInit 12, OFF_INTDEFAULT
	protModeExcInit 13, OFF_INTGP
	protModeExcInit 14, OFF_INTPAGEFAULT
	protModeExcInit 15, OFF_INTDEFAULT
	protModeExcInit 16, OFF_INTDEFAULT
%endmacro
