TYPE_ARITH    equ  0 ; multiple values for eAX and eDX
TYPE_ARITH1   equ  1 ; multiple values for eAX, 1 value for eDX
TYPE_ARITH1D  equ  2 ; 1 value for eAX, multiple values for eDX
TYPE_LOGIC    equ  3
TYPE_MULTIPLY equ  4
TYPE_DIVIDE   equ  5
TYPE_SHIFTS_1 equ  6
TYPE_SHIFTS_R equ  7

SIZE_BYTE     equ  0
SIZE_SHORT    equ  1
SIZE_LONG     equ  2

%macro	defOp	6
	%ifidni %3,al
	%assign size SIZE_BYTE
	%define msrc dl
	%elifidni %3,dl
	%assign size SIZE_BYTE
	%elifidni %3,ax
	%assign size SIZE_SHORT
	%define msrc dx
	%elifidni %3,dx
	%assign size SIZE_SHORT
	%else
	%assign size SIZE_LONG
	%define msrc edx
	%endif
	db	%%end-%%beg,%6,size
%%name:
	db	%1,' ',0
%%beg:
	%ifidni %4,none
	%2	%3
	%elifidni %4,mem
	mov [0], msrc
	%2	%3,[0]
	%elifidni %5,none
	%2	%3,%4
	%else
	%2	%3,%4,%5
	%endif
	ret
%%end:
%endmacro

%macro defOp0 4
	%ifidni %3,b
	%assign size SIZE_BYTE
	%elifidni %3,w
	%assign size SIZE_SHORT
	%else
	%assign size SIZE_LONG
	%endif
	db %%end-%%beg,%4,size
%%name:
	db %1,' ',0
%%beg:
	%2
	ret
%%end:
%endmacro

%macro defOpSh 5
	%ifidni %3,al
	%assign size SIZE_BYTE
	%elifidni %3,ax
	%assign size SIZE_SHORT
	%else ; eax
	%assign size SIZE_LONG
	%endif
	db	%%end-%%beg,%5,size
%%name:
	db	%1,' ',0
%%beg:
	stc
	%ifidni %4,cl
	xchg cl,dl
	%2	%3,cl
	xchg cl,dl
	%else
	%2	%3,%4
	%endif
	ret
%%end:
%endmacro

ALLOPS equ 1

tableOps:
	defOp0   "CBW",cbw,b,TYPE_ARITH1                       ; 66 98
	defOp0   "CWDE",cwde,w,TYPE_ARITH1                     ;    98
	defOp0   "CWD",cwd,w,TYPE_ARITH1                       ; 66 99
	defOp0   "CDQ",cdq,d,TYPE_ARITH1                       ;    99
	defOp    "ADD",add,al,dl,none,TYPE_ARITH               ;    00 D0
	defOp    "ADD",add,ax,dx,none,TYPE_ARITH               ; 66 01 D0
	defOp    "ADD",add,eax,edx,none,TYPE_ARITH             ;    01 D0
	defOp    "OR",or,al,dl,none,TYPE_LOGIC                 ;    08 D0
	defOp    "OR",or,ax,dx,none,TYPE_LOGIC                 ; 66 09 D0
	defOp    "OR",or,eax,edx,none,TYPE_LOGIC               ;    09 D0
	defOp    "ADC",adc,al,dl,none,TYPE_ARITH               ;    10 D0
	defOp    "ADC",adc,ax,dx,none,TYPE_ARITH               ; 66 11 D0
	defOp    "ADC",adc,eax,edx,none,TYPE_ARITH             ;    11 D0
	defOp    "ADC",adc,al,0xFF,none,TYPE_ARITH1            ;    14 FF
	defOp    "ADC",adc,ax,0x8002,none,TYPE_ARITH1          ; 66 15 0280
	defOp    "ADC",adc,eax,0x80000002,none,TYPE_ARITH1     ;    15 02000080
	defOp    "ADC",adc,ax,byte 0xFF,none,TYPE_ARITH1       ; 66 83 D0 FF
	defOp    "ADC",adc,eax,byte 0xFF,none,TYPE_ARITH1      ;    83 D0 FF
	defOp    "ADC",adc,dl,0xFF,none,TYPE_ARITH1D           ;    80 D2 FF
	defOp    "ADC",adc,dx,0x8002,none,TYPE_ARITH1D         ; 66 81 D2 0280
	defOp    "ADC",adc,edx,0x80000002,none,TYPE_ARITH1D    ;    81 D2 02000080
	defOp    "ADC",adc,al,mem,none,TYPE_ARITH              ;    12 05 00000000
	defOp    "ADC",adc,ax,mem,none,TYPE_ARITH              ; 66 13 05 00000000
	defOp    "ADC",adc,eax,mem,none,TYPE_ARITH             ;    13 05 00000000
	defOp    "SBB",sbb,al,dl,none,TYPE_ARITH               ;    18 D0
	defOp    "SBB",sbb,ax,dx,none,TYPE_ARITH               ; 66 19 D0
	defOp    "SBB",sbb,eax,edx,none,TYPE_ARITH             ;    19 D0
	defOp    "AND",and,al,dl,none,TYPE_LOGIC               ;    20 D0
	defOp    "AND",and,ax,dx,none,TYPE_LOGIC               ; 66 21 D0
	defOp    "AND",and,eax,edx,none,TYPE_LOGIC             ;    21 D0
	defOp    "SUB",sub,al,dl,none,TYPE_ARITH               ;    28 D0
	defOp    "SUB",sub,ax,dx,none,TYPE_ARITH               ; 66 29 D0
	defOp    "SUB",sub,eax,edx,none,TYPE_ARITH             ;    29 D0
	defOp    "XOR",xor,al,dl,none,TYPE_LOGIC               ;    30 D0
	defOp    "XOR",xor,ax,dx,none,TYPE_LOGIC               ; 66 31 D0
	defOp    "XOR",xor,eax,edx,none,TYPE_LOGIC             ;    31 D0
	defOp    "CMP",cmp,al,dl,none,TYPE_ARITH               ;    38 D0
	defOp    "CMP",cmp,ax,dx,none,TYPE_ARITH               ; 66 39 D0
	defOp    "CMP",cmp,eax,edx,none,TYPE_ARITH             ;    39 D0
	defOp    "INC",inc,al,none,none,TYPE_ARITH1            ;    FE C0
	defOp    "INC",inc,ax,none,none,TYPE_ARITH1            ; 66 40
	defOp    "INC",inc,eax,none,none,TYPE_ARITH1           ;    40
	defOp    "DEC",dec,al,none,none,TYPE_ARITH1            ;    FE C8
	defOp    "DEC",dec,ax,none,none,TYPE_ARITH1            ; 66 48
	defOp    "DEC",dec,eax,none,none,TYPE_ARITH1           ;    48
	defOp    "NEG",neg,al,none,none,TYPE_ARITH1            ;    F6 D8
	defOp    "NEG",neg,ax,none,none,TYPE_ARITH1            ; 66 F7 D8
	defOp    "NEG",neg,eax,none,none,TYPE_ARITH1           ;    F7 D8
	defOp    "NOT",not,al,none,none,TYPE_ARITH1            ;    F6 D0
	defOp    "NOT",not,ax,none,none,TYPE_ARITH1            ; 66 F7 D0
	defOp    "NOT",not,eax,none,none,TYPE_ARITH1           ;    F7 D0
	defOp    "MULA",mul,dl,none,none,TYPE_MULTIPLY         ;    F6 E2
	defOp    "MULA",mul,dx,none,none,TYPE_MULTIPLY         ; 66 F7 E2
	defOp    "MULA",mul,edx,none,none,TYPE_MULTIPLY        ;    F7 E2
	defOp    "IMULA",imul,dl,none,none,TYPE_MULTIPLY       ;    F6 EA
	defOp    "IMULA",imul,dx,none,none,TYPE_MULTIPLY       ; 66 F7 EA
	defOp    "IMULA",imul,edx,none,none,TYPE_MULTIPLY      ;    F7 EA
	defOp    "IMUL",imul,ax,dx,none,TYPE_MULTIPLY          ; 66 0FAF C2
	defOp    "IMUL",imul,eax,edx,none,TYPE_MULTIPLY        ;    0FAF C2
	defOp    "IMUL8",imul,ax,dx,0x77,TYPE_MULTIPLY         ; 66 6B C2 77
	defOp    "IMUL8",imul,ax,dx,-0x77,TYPE_MULTIPLY        ; 66 6B C2 89
	defOp    "IMUL8",imul,eax,edx,0x77,TYPE_MULTIPLY       ;    6B C2 77
	defOp    "IMUL8",imul,eax,edx,-0x77,TYPE_MULTIPLY      ;    6B C2 89
	defOp    "IMUL16",imul,ax,0x777,none,TYPE_MULTIPLY     ; 66 69 C0 7707
	defOp    "IMUL32",imul,eax,0x777777,none,TYPE_MULTIPLY ;    69 C0 77777700
	defOp    "DIVDL",div,dl,none,none,TYPE_DIVIDE          ;    F6 F2
	defOp    "DIVDX",div,dx,none,none,TYPE_DIVIDE          ; 66 F7 F2
	defOp    "DIVEDX",div,edx,none,none,TYPE_DIVIDE        ;    F7 F2
	defOp    "DIVAL",div,al,none,none,TYPE_DIVIDE          ;    F6 F0
	defOp    "DIVAX",div,ax,none,none,TYPE_DIVIDE          ; 66 F7 F0
	defOp    "DIVEAX",div,eax,none,none,TYPE_DIVIDE        ;    F7 F0
	defOp    "IDIVDL",idiv,dl,none,none,TYPE_DIVIDE        ;    F6 FA
	defOp    "IDIVDX",idiv,dx,none,none,TYPE_DIVIDE        ; 66 F7 FA
	defOp    "IDIVEDX",idiv,edx,none,none,TYPE_DIVIDE      ;    F7 FA
	defOp    "IDIVAL",idiv,al,none,none,TYPE_DIVIDE        ;    F6 F8
	defOp    "IDIVAX",idiv,ax,none,none,TYPE_DIVIDE        ; 66 F7 F8
	defOp    "IDIVEAX",idiv,eax,none,none,TYPE_DIVIDE      ;    F7 F8
	defOpSh  "SAL1",sal,al,1,TYPE_SHIFTS_1    ;    D0 E0
	defOpSh  "SAL1",sal,ax,1,TYPE_SHIFTS_1    ; 66 D1 E0
	defOpSh  "SAL1",sal,eax,1,TYPE_SHIFTS_1   ;    D1 E0
	defOpSh  "SALi",sal,al,7,TYPE_SHIFTS_R    ;    C0 E007
	defOpSh  "SALi",sal,ax,7,TYPE_SHIFTS_R    ; 66 C1 E007
	defOpSh  "SALi",sal,eax,7,TYPE_SHIFTS_R   ;    C1 E007
	defOpSh  "SALr",sal,al,cl,TYPE_SHIFTS_R   ;    D2 E0
	defOpSh  "SALr",sal,ax,cl,TYPE_SHIFTS_R   ; 66 D3 E0
	defOpSh  "SALr",sal,eax,cl,TYPE_SHIFTS_R  ;    D3 E0
	defOpSh  "SAR1",sar,al,1,TYPE_SHIFTS_1    ;    D0 F8
	defOpSh  "SAR1",sar,ax,1,TYPE_SHIFTS_1    ; 66 D1 F8
	defOpSh  "SAR1",sar,eax,1,TYPE_SHIFTS_1   ;    D1 F8
	defOpSh  "SARi",sar,al,7,TYPE_SHIFTS_R    ;    C0 F807
	defOpSh  "SARi",sar,ax,7,TYPE_SHIFTS_R    ; 66 C1 F807
	defOpSh  "SARi",sar,eax,7,TYPE_SHIFTS_R   ;    C1 F807
	defOpSh  "SARr",sar,al,cl,TYPE_SHIFTS_R   ;    D2 F8
	defOpSh  "SARr",sar,ax,cl,TYPE_SHIFTS_R   ; 66 D3 F8
	defOpSh  "SARr",sar,eax,cl,TYPE_SHIFTS_R  ;    D3 F8
	defOpSh  "SHR1",shr,al,1,TYPE_SHIFTS_1    ;    D0 E8
	defOpSh  "SHR1",shr,ax,1,TYPE_SHIFTS_1    ; 66 D1 E8
	defOpSh  "SHR1",shr,eax,1,TYPE_SHIFTS_1   ;    D1 E8
	defOpSh  "SHRi",shr,al,7,TYPE_SHIFTS_R    ;    C0 E807
	defOpSh  "SHRi",shr,ax,7,TYPE_SHIFTS_R    ; 66 C1 E807
	defOpSh  "SHRi",shr,eax,7,TYPE_SHIFTS_R   ;    C1 E807
	defOpSh  "SHRr",shr,al,cl,TYPE_SHIFTS_R   ;    D2 E8
	defOpSh  "SHRr",shr,ax,cl,TYPE_SHIFTS_R   ; 66 D3 E8
	defOpSh  "SHRr",shr,eax,cl,TYPE_SHIFTS_R  ;    D3 E8
	defOpSh  "ROL1",rol,al,1,TYPE_SHIFTS_1    ;    D0 C0
	defOpSh  "ROL1",rol,ax,1,TYPE_SHIFTS_1    ; 66 D1 C0
	defOpSh  "ROL1",rol,eax,1,TYPE_SHIFTS_1   ;    D1 C0
	defOpSh  "ROLi",rol,al,7,TYPE_SHIFTS_1    ;    C0 C007
	defOpSh  "ROLi",rol,ax,7,TYPE_SHIFTS_1    ; 66 C1 C007
	defOpSh  "ROLi",rol,eax,7,TYPE_SHIFTS_1   ;    C1 C007
	defOpSh  "ROLr",rol,al,cl,TYPE_SHIFTS_R   ;    D2 C0
	defOpSh  "ROLr",rol,ax,cl,TYPE_SHIFTS_R   ; 66 D3 C0
	defOpSh  "ROLr",rol,eax,cl,TYPE_SHIFTS_R  ;    D3 C0
	defOpSh  "ROR1",ror,al,1,TYPE_SHIFTS_1    ;    D0 C8
	defOpSh  "ROR1",ror,ax,1,TYPE_SHIFTS_1    ; 66 D1 C8
	defOpSh  "ROR1",ror,eax,1,TYPE_SHIFTS_1   ;    D1 C8
	defOpSh  "RORi",ror,al,7,TYPE_SHIFTS_1    ;    C0 C807
	defOpSh  "RORi",ror,ax,7,TYPE_SHIFTS_1    ; 66 C1 C807
	defOpSh  "RORi",ror,eax,7,TYPE_SHIFTS_1   ;    C1 C807
	defOpSh  "RORr",ror,al,cl,TYPE_SHIFTS_R   ;    D2 C8
	defOpSh  "RORr",ror,ax,cl,TYPE_SHIFTS_R   ; 66 D3 C8
	defOpSh  "RORr",ror,eax,cl,TYPE_SHIFTS_R  ;    D3 C8
	defOpSh  "RCL1",rcl,al,1,TYPE_SHIFTS_1    ;    D0 D0
	defOpSh  "RCL1",rcl,ax,1,TYPE_SHIFTS_1    ; 66 D1 D0
	defOpSh  "RCL1",rcl,eax,1,TYPE_SHIFTS_1   ;    D1 D0
	defOpSh  "RCLi",rcl,al,7,TYPE_SHIFTS_1    ;    C0 D007
	defOpSh  "RCLi",rcl,ax,7,TYPE_SHIFTS_1    ; 66 C1 D007
	defOpSh  "RCLi",rcl,eax,7,TYPE_SHIFTS_1   ;    C1 D007
	defOpSh  "RCLr",rcl,al,cl,TYPE_SHIFTS_R   ;    D2 D0
	defOpSh  "RCLr",rcl,ax,cl,TYPE_SHIFTS_R   ; 66 D3 D0
	defOpSh  "RCLr",rcl,eax,cl,TYPE_SHIFTS_R  ;    D3 D0
	defOpSh  "RCR1",rol,al,1,TYPE_SHIFTS_1    ;    D0 C0
	defOpSh  "RCR1",rol,ax,1,TYPE_SHIFTS_1    ; 66 D1 C0
	defOpSh  "RCR1",rol,eax,1,TYPE_SHIFTS_1   ;    D1 C0
	defOpSh  "RCRi",rol,al,7,TYPE_SHIFTS_1    ;    C0 C007
	defOpSh  "RCRi",rol,ax,7,TYPE_SHIFTS_1    ; 66 C1 C007
	defOpSh  "RCRi",rol,eax,7,TYPE_SHIFTS_1   ;    C1 C007
	defOpSh  "RCRr",rol,al,cl,TYPE_SHIFTS_R   ;    D2 C0
	defOpSh  "RCRr",rol,ax,cl,TYPE_SHIFTS_R   ; 66 D3 C0
	defOpSh  "RCRr",rol,eax,cl,TYPE_SHIFTS_R  ;    D3 C0

	db 0

	align	4

typeMasks:
	dd PS_ARITH
	dd PS_ARITH
	dd PS_ARITH
	dd PS_LOGIC
	dd PS_MULTIPLY
	dd PS_DIVIDE
	dd PS_SHIFTS_1
	dd PS_SHIFTS_R

arithValues:
.bvals:	dd	0x00,0x01,0x02,0x7E,0x7F,0x80,0x81,0xFE,0xFF
	ARITH_BYTES equ ($-.bvals)/4

.wvals:	dd	0x0000,0x0001,0x0002,0x7FFE,0x7FFF,0x8000,0x8001,0xFFFE,0xFFFF
	ARITH_WORDS equ ($-.wvals)/4

.dvals:	dd	0x00000000,0x00000001,0x00000002,0x7FFFFFFE,0x7FFFFFFF,0x80000000,0x80000001,0xFFFFFFFE,0xFFFFFFFF
	ARITH_DWORDS equ ($-.dvals)/4

muldivValues:
.bvals:	dd	0x00,0x01,0x02,0x3F,0x40,0x41,0x7E,0x7F,0x80,0x81,0xFE,0xFF
	MULDIV_BYTES equ ($-.bvals)/4

.wvals:	dd	0x0000,0x0001,0x0002,0x3FFF,0x4000,0x4001,0x7FFE,0x7FFF,0x8000,0x8001,0xFFFE,0xFFFF
	MULDIV_WORDS equ ($-.wvals)/4

.dvals:	dd	0x00000000,0x00000001,0x00000002,0x3FFFFFFF,0x40000000,0x40000001,0x7FFFFFFE,0x7FFFFFFF,0x80000000,0x80000001,0xFFFFFFFE,0xFFFFFFFF
	MULDIV_DWORDS equ ($-.dvals)/4

shiftsValues:
.bvals:	dd	0x00,0x01,0x02,0x7E,0x7F,0x80,0x81,0xFE,0xFF
	SHIFTS_BYTES equ ($-.bvals)/4

.wvals:	dd	0x0000,0x0001,0x0181,0x7FFE,0x7FFF,0x8000,0x8001,0xFFFE,0xFFFF
	SHIFTS_WORDS equ ($-.wvals)/4

.dvals:	dd	0x00000000,0x00000001,0x00018001,0x7FFFFFFE,0x7FFFFFFF,0x80000000,0x80000001,0xFFFFFFFE,0xFFFFFFFF
	SHIFTS_DWORDS equ ($-.dvals)/4

shiftsValuesR:
.bvals:	dd	0x00,0x01,0x02,0x08
	SHIFTS_BYTES_R equ ($-.bvals)/4

.wvals:	dd	0x0000,0x0001,0x0002,0x0010
	SHIFTS_WORDS_R equ ($-.wvals)/4

.dvals:	dd	0x00000000,0x00000001,0x00000002,0x0000001F,0x00000020
	SHIFTS_DWORDS_R equ ($-.dvals)/4


typeValues:
	;
	; Values for TYPE_ARITH
	;
	dd	ARITH_BYTES,arithValues,ARITH_BYTES,arithValues
	dd	ARITH_BYTES+ARITH_WORDS,arithValues,ARITH_BYTES+ARITH_WORDS,arithValues
	dd	ARITH_BYTES+ARITH_WORDS+ARITH_DWORDS,arithValues,ARITH_BYTES+ARITH_WORDS+ARITH_DWORDS,arithValues
	dd	0,0,0,0
	;
	; Values for TYPE_ARITH1
	;
	dd	ARITH_BYTES,arithValues,1,arithValues
	dd	ARITH_BYTES+ARITH_WORDS,arithValues,1,arithValues
	dd	ARITH_BYTES+ARITH_WORDS+ARITH_DWORDS,arithValues,1,arithValues
	dd	0,0,0,0
	;
	; Values for TYPE_ARITH1D
	;
	dd	1,arithValues,ARITH_BYTES,arithValues
	dd	1,arithValues,ARITH_BYTES+ARITH_WORDS,arithValues
	dd	1,arithValues,ARITH_BYTES+ARITH_WORDS+ARITH_DWORDS,arithValues
	dd	0,0,0,0
	;
	; Values for TYPE_LOGIC (using ARITH values for now)
	;
	dd	ARITH_BYTES,arithValues,ARITH_BYTES,arithValues
	dd	ARITH_BYTES+ARITH_WORDS,arithValues,ARITH_BYTES+ARITH_WORDS,arithValues
	dd	ARITH_BYTES+ARITH_WORDS+ARITH_DWORDS,arithValues,ARITH_BYTES+ARITH_WORDS+ARITH_DWORDS,arithValues
	dd	0,0,0,0
	;
	; Values for TYPE_MULTIPLY (a superset of ARITH values)
	;
	dd	MULDIV_BYTES,muldivValues,MULDIV_BYTES,muldivValues
	dd	MULDIV_BYTES+MULDIV_WORDS,muldivValues,MULDIV_BYTES+MULDIV_WORDS,muldivValues
	dd	MULDIV_BYTES+MULDIV_WORDS+MULDIV_DWORDS,muldivValues,MULDIV_BYTES+MULDIV_WORDS+MULDIV_DWORDS,muldivValues
	dd	0,0,0,0
	;
	; Values for TYPE_DIVIDE
	;
	dd	MULDIV_BYTES,muldivValues,MULDIV_BYTES,muldivValues
	dd	MULDIV_BYTES+MULDIV_WORDS,muldivValues,MULDIV_BYTES+MULDIV_WORDS,muldivValues
	dd	MULDIV_BYTES+MULDIV_WORDS+MULDIV_DWORDS,muldivValues,MULDIV_BYTES+MULDIV_WORDS+MULDIV_DWORDS,muldivValues
	dd	0,0,0,0
	;
	; Values for TYPE_SHIFTS_1
	;
	dd	SHIFTS_BYTES,shiftsValues,1,shiftsValues
	dd	SHIFTS_BYTES+SHIFTS_WORDS,shiftsValues,1,shiftsValues
	dd	SHIFTS_BYTES+SHIFTS_WORDS+SHIFTS_DWORDS,shiftsValues,1,shiftsValues
	dd	0,0,0,0
	;
	; Values for TYPE_SHIFTS_R
	;
	dd	SHIFTS_BYTES,shiftsValues,SHIFTS_BYTES_R,shiftsValuesR
	dd	SHIFTS_BYTES+SHIFTS_WORDS,shiftsValues,SHIFTS_BYTES_R+SHIFTS_WORDS_R,shiftsValuesR
	dd	SHIFTS_BYTES+SHIFTS_WORDS+SHIFTS_DWORDS,shiftsValues,SHIFTS_BYTES_R+SHIFTS_WORDS_R+SHIFTS_DWORDS_R,shiftsValuesR
	dd	0,0,0,0
