; Procedures for 32 bit code segment

initIntGateProt:
	pushad
	pushf
	initIntGate
	popf
	popad
	ret


initDescriptorProt:
	pushad
	pushf
	initDescriptor
	popf
	popad
	ret
