;
; Advances the base address of data segments used by tests, D1_SEG_PROT and
; D2_SEG_PROT.
;
; Loads DS with D1_SEG_PROT and ES with D2_SEG_PROT.
;
%macro advTestSegProt 0
	advTestBase
	updLDTDescBase D1_SEG_PROT,TEST_BASE1
	updLDTDescBase D2_SEG_PROT,TEST_BASE2
	mov    dx, D1_SEG_PROT
	mov    ds, dx
	mov    dx, D2_SEG_PROT
	mov    es, dx
%endmacro


;
;   Defines an interrupt gate in ROM, given a selector (%1) and an offset (%2)
;
%macro defIntGate 2
	dw    (%2 & 0xffff) ; OFFSET 15-0
	dw    %1 ; SELECTOR
	dw    ACC_TYPE_GATE386_INT | ACC_PRESENT ; acc byte
	dw    (%2 >> 16) & 0xffff ; OFFSET 31-16
%endmacro

%assign GDTSelDesc 0
;
;   Defines a GDT descriptor in ROM, given a name (%1), base (%2), limit (%3),
;   acc byte (%4), and ext nibble (%5)
;
%macro defGDTDescROM 1-5 0,0,0,0
	%assign %1 GDTSelDesc
	dw (%3 & 0x0000ffff) ; LIMIT 15-0
	dw (%2 & 0x0000ffff) ; BASE 15-0
	dw ((%2 & 0x00ff0000) >> 16) | %4 ; BASE 23-16 | acc byte
	dw ((%3 & 0x000f0000) >> 16) | %5 | ((%2 & 0xff000000) >> 16) ; LIMIT 19-16 | ext nibble | BASE 31-24
	%assign GDTSelDesc GDTSelDesc+8
%endmacro
;
;   Defines a GDT descriptor in RAM, given a name (%1), base (%2), limit (%3),
;   acc byte (%4), and ext nibble (%5)
;
%macro defGDTDesc 1-5 0,0,0,0
	%assign %1 GDTSelDesc
	lds  ebx, [cs:ptrGDTreal] ; this macro is used in real mode to set up prot mode env.
	mov  eax, %1
	mov  esi, %2
	mov  edi, %3
	mov  dx,  %4|%5
	initDescriptor
	%assign GDTSelDesc GDTSelDesc+8
%endmacro

;
;   Defines a LDT descriptor, given a name (%1), base (%2), limit (%3), type (%4), and ext (%5)
;
%assign LDTSelDesc 4
%macro defLDTDesc 1-5 0,0,0,0
	%assign %1 LDTSelDesc
	lds  ebx, [cs:ptrLDTprot]  ; this macro is used in prot mode to set up prot mode env.
	mov  eax, %1
	mov  esi, %2
	mov  edi, %3
	mov  dx,  %4|%5
	initDescriptor
	%assign LDTSelDesc LDTSelDesc+8
%endmacro

;
; Updates the access byte of a descriptor in the LDT
; %1 LDT selector
; %2 access byte new value (ACC_* or'd equs)
; Uses DS
%macro updLDTDescAcc 2
	pushad
	pushf
	lds  ebx, [cs:ptrLDTprot]
	add  ebx, (%1) & 0xFFF8
	mov  byte [ebx+5], (%2)>>8 ; acc byte
	popf
	popad
%endmacro

;
; Updates the base of a descriptor in the LDT
; %1 LDT selector
; %2 new base
; Uses DS,EBX,flags
%macro updLDTDescBase 2
	lds  ebx, [cs:ptrLDTprot]
	add  ebx, (%1) & 0xFFF8
	mov  word [ebx+2], (%2)&0xFFFF     ; BASE 15-0
	mov  byte [ebx+4], ((%2)>>16)&0xFF ; BASE 23-16
	mov  byte [ebx+7], ((%2)>>24)&0xFF ; BASE 31-24
%endmacro

;
; Updates a PTE's flags
; %1 PTE index
; %2 new flags (PTE's bits 11-0)
; Uses FS
;
%macro updPTEFlags 2
	pushad
	pushf
	lfs  ebx, [cs:ptrPTprot]
	mov  eax, %1
	and  [fs:ebx + eax*4], dword PTE_FRAME
	or   [fs:ebx + eax*4], dword %2
	mov  eax, PAGE_DIR_ADDR
	mov  cr3, eax ; flush the page translation cache
	popf
	popad
%endmacro

;
; Updates a PTE's flag
; %1 PTE index
; %2 PTE flags mask
; %3 new flag
; Uses FS
;
%macro setPTEFlag 3
	pushad
	pushf
	lfs  ebx, [cs:ptrPTprot]
	mov  eax, %1
	mov  ecx, %2
	not  ecx
	and  [fs:ebx + eax*4], ecx
	or   [fs:ebx + eax*4], dword %3
	mov  eax, PAGE_DIR_ADDR
	mov  cr3, eax ; flush the page translation cache
	popf
	popad
%endmacro

;
; Initializes an interrupt gate in system memory
;
; %1 vector
; %2 offset
;
; Uses EAX, ECX
;
%macro protModeExcInitReal 2
; executes in real mode
	mov    eax, %1
	mov    ecx, %2
	call   initIntGateReal
%endmacro
%macro protModeExcInitProt 2
; executes in protected mode
	mov    eax, %1
	mov    ecx, %2
	call   initIntGateProt
%endmacro

;
; Loads DS:EBX with a pointer to the prot mode IDT
;
%macro loadProtModeIDTptr 0
	lds    ebx, [cs:ptrIDTprot]
%endmacro

;
; Loads SS:ESP with a pointer to the prot mode stack
;
%macro loadProtModeStack 0
	lss    esp, [cs:ptrSSprot]
%endmacro

;
; Initializes the protected mode IDT in memory
;
; This macro executes in real mode.
;
%macro initProtModeIDT 0
	lds    ebx, [cs:ptrIDTreal]

	protModeExcInitReal  0, OFF_INTDEFAULT
	protModeExcInitReal  1, OFF_INTDEFAULT
	protModeExcInitReal  2, OFF_INTDEFAULT
	protModeExcInitReal  3, OFF_INTDEFAULT
	protModeExcInitReal  4, OFF_INTDEFAULT
	protModeExcInitReal  5, OFF_INTDEFAULT
	protModeExcInitReal  6, OFF_INTDEFAULT
	protModeExcInitReal  7, OFF_INTDEFAULT
	protModeExcInitReal  8, OFF_INTDEFAULT
	protModeExcInitReal  9, OFF_INTDEFAULT
	protModeExcInitReal 10, OFF_INTDEFAULT
	protModeExcInitReal 11, OFF_INTDEFAULT
	protModeExcInitReal 12, OFF_INTDEFAULT
	protModeExcInitReal 13, OFF_INTDEFAULT
	protModeExcInitReal 14, OFF_INTDEFAULT
	protModeExcInitReal 15, OFF_INTDEFAULT
	protModeExcInitReal 16, OFF_INTDEFAULT
%endmacro

;
; Set a int gate on the IDT in protected mode
;
; %1: vector
; %2: offset
;
; Uses EAX, ECX, DS, EBX
; the stack must be initialized
;
%macro setProtModeIntGate 2
	pushad
	mov dx, ds  ; save ds
	loadProtModeIDTptr
	protModeExcInitProt %1, %2
	mov ds, dx  ; restore ds
	popad
%endmacro

;
; Tests a fault
;
; %1: vector
; %2: expected error code
; %3: fault causing instruction
;
; the stack must be initialized
;
%macro protModeFaultTest 3+
	setProtModeIntGate %1, %%continue
%%test:
	%3
	jmp    error
%%continue:
	protModeExcCheck %1, %2, %%test
	setProtModeIntGate %1, OFF_INTDEFAULT
%endmacro

;
; Checks exception result and restores the previous handler
;
; %1: vector
; %2: expected error code
; %3: expected pushed value of EIP
;
%macro protModeExcCheck 3
	%if %1 == 8 || (%1 > 10 && %1 < 14)
	%assign exc_errcode 4
	cmp    [ss:esp], dword %2
	jne    error
	%else
	%assign exc_errcode 0
	%endif
	cmp    [ss:esp+exc_errcode+4], dword C_SEG_PROT32
	jne    error
	cmp    [ss:esp+exc_errcode], dword %3
	jne    error
	add    esp, 12+exc_errcode
%endmacro
