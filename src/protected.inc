;
;   Defines an interrupt gate, given a selector (%1) and an offset (%2)
;
%macro	defGate	2
	dw    (%2 & 0xffff)
	dw    %1
	dw    ACC_TYPE_GATE386_INT | ACC_PRESENT
	dw    (%2 >> 16) & 0xffff
%endmacro

;
;   Defines a descriptor, given a name (%1), base (%2), limit (%3), type (%4), and ext (%5)
;
%assign	selDesc	0

%macro	defDesc	1-5 0,0,0,0
	%assign %1 selDesc
	dw	(%3 & 0x0000ffff)
	dw	(%2 & 0x0000ffff)
	%if selDesc = 0
	dw	((%2 & 0x00ff0000) >> 16) | %4 | (0 << 13)
	%else
	dw	((%2 & 0x00ff0000) >> 16) | %4 | (0 << 13) | ACC_PRESENT
	%endif
	dw	((%3 & 0x000f0000) >> 16) | %5 | ((%2 & 0xff000000) >> 16)
	%assign selDesc selDesc+8
%endmacro

