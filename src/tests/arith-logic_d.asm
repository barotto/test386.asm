TYPE_ARITH    equ  0
TYPE_ARITH1   equ  1
TYPE_LOGIC    equ  2
TYPE_MULTIPLY equ  3
TYPE_DIVIDE   equ  4

SIZE_BYTE     equ  0
SIZE_SHORT    equ  1
SIZE_LONG     equ  2

%macro	defOp	6
	%ifidni %3,al
	%assign size SIZE_BYTE
	%elifidni %3,dl
	%assign size SIZE_BYTE
	%elifidni %3,ax
	%assign size SIZE_SHORT
	%elifidni %3,dx
	%assign size SIZE_SHORT
	%else
	%assign size SIZE_LONG
	%endif
	db	%%end-%%beg,%6,size
%%name:
	db	%1,' ',0
%%beg:
	%ifidni %4,none
	%2	%3
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
	db 0

	align	4

typeMasks:
	dd PS_ARITH
	dd PS_ARITH
	dd PS_LOGIC
	dd PS_MULTIPLY
	dd PS_DIVIDE

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
