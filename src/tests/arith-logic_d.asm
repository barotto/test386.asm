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
	db	%1,0
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

strEAX: db  "EAX=",0
strEDX: db  "EDX=",0
strPS:  db  "PS=",0
strDE:  db  "#DE ",0 ; when this is displayed, it indicates a Divide Error exception
achSize db  "BWD"

ALLOPS equ 1

tableOps:
	defOp    "ADD",add,al,dl,none,TYPE_ARITH
	defOp    "ADD",add,ax,dx,none,TYPE_ARITH
	defOp    "ADD",add,eax,edx,none,TYPE_ARITH
	defOp    "OR",or,al,dl,none,TYPE_LOGIC
	defOp    "OR",or,ax,dx,none,TYPE_LOGIC
	defOp    "OR",or,eax,edx,none,TYPE_LOGIC
	defOp    "ADC",adc,al,dl,none,TYPE_ARITH
	defOp    "ADC",adc,ax,dx,none,TYPE_ARITH
	defOp    "ADC",adc,eax,edx,none,TYPE_ARITH
	defOp    "SBB",sbb,al,dl,none,TYPE_ARITH
	defOp    "SBB",sbb,ax,dx,none,TYPE_ARITH
	defOp    "SBB",sbb,eax,edx,none,TYPE_ARITH
	defOp    "AND",and,al,dl,none,TYPE_LOGIC
	defOp    "AND",and,ax,dx,none,TYPE_LOGIC
	defOp    "AND",and,eax,edx,none,TYPE_LOGIC
	defOp    "SUB",sub,al,dl,none,TYPE_ARITH
	defOp    "SUB",sub,ax,dx,none,TYPE_ARITH
	defOp    "SUB",sub,eax,edx,none,TYPE_ARITH
	defOp    "XOR",xor,al,dl,none,TYPE_LOGIC
	defOp    "XOR",xor,ax,dx,none,TYPE_LOGIC
	defOp    "XOR",xor,eax,edx,none,TYPE_LOGIC
	defOp    "CMP",cmp,al,dl,none,TYPE_ARITH
	defOp    "CMP",cmp,ax,dx,none,TYPE_ARITH
	defOp    "CMP",cmp,eax,edx,none,TYPE_ARITH
	defOp    "INC",inc,al,none,none,TYPE_ARITH1
	defOp    "INC",inc,ax,none,none,TYPE_ARITH1
	defOp    "INC",inc,eax,none,none,TYPE_ARITH1
	defOp    "DEC",dec,al,none,none,TYPE_ARITH1
	defOp    "DEC",dec,ax,none,none,TYPE_ARITH1
	defOp    "DEC",dec,eax,none,none,TYPE_ARITH1
	defOp    "MULA",mul,dl,none,none,TYPE_MULTIPLY
	defOp    "MULA",mul,dx,none,none,TYPE_MULTIPLY
	defOp    "MULA",mul,edx,none,none,TYPE_MULTIPLY
	defOp    "IMULA",imul,dl,none,none,TYPE_MULTIPLY
	defOp    "IMULA",imul,dx,none,none,TYPE_MULTIPLY
	defOp    "IMULA",imul,edx,none,none,TYPE_MULTIPLY
	defOp    "IMUL",imul,ax,dx,none,TYPE_MULTIPLY
	defOp    "IMUL",imul,eax,edx,none,TYPE_MULTIPLY
	defOp    "IMUL8",imul,ax,dx,0x77,TYPE_MULTIPLY
	defOp    "IMUL8",imul,ax,dx,-0x77,TYPE_MULTIPLY
	defOp    "IMUL8",imul,eax,edx,0x77,TYPE_MULTIPLY
	defOp    "IMUL8",imul,eax,edx,-0x77,TYPE_MULTIPLY
	defOp    "IMUL16",imul,ax,0x777,none,TYPE_MULTIPLY
	defOp    "IMUL32",imul,eax,0x777777,none,TYPE_MULTIPLY
	defOp    "DIVDL",div,dl,none,none,TYPE_DIVIDE
	defOp    "DIVDX",div,dx,none,none,TYPE_DIVIDE
	defOp    "DIVEDX",div,edx,none,none,TYPE_DIVIDE
	defOp    "DIVAL",div,al,none,none,TYPE_DIVIDE
	defOp    "DIVAX",div,ax,none,none,TYPE_DIVIDE
	defOp    "DIVEAX",div,eax,none,none,TYPE_DIVIDE
	defOp    "IDIVDL",idiv,dl,none,none,TYPE_DIVIDE
	defOp    "IDIVDX",idiv,dx,none,none,TYPE_DIVIDE
	defOp    "IDIVEDX",idiv,edx,none,none,TYPE_DIVIDE
	defOp    "IDIVAL",idiv,al,none,none,TYPE_DIVIDE
	defOp    "IDIVAX",idiv,ax,none,none,TYPE_DIVIDE
	defOp    "IDIVEAX",idiv,eax,none,none,TYPE_DIVIDE
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
