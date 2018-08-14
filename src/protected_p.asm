; Procedures for 32 bit code segment

initIntGateMemProt:
	pushad
	pushf
	initIntGateMem
	popf
	popad
	ret


initSegDescMemProt:
	pushad
	pushf
	initSegDescMem
	popf
	popad
	ret
