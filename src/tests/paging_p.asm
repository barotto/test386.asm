PF_HANDLER_SIG equ 0x50465046

PageFaultHandler:
	; compare the expected error code in EAX with the one pushed on the stack
	pop   ebx
	cmp   eax, ebx
	jne   error
	; this handler is expected to run in ring 0
	testCPL 0
	; check CR2 register, it must contain the linear address TESTPAGE_LIN
	mov   eax, cr2
	cmp   eax, TESTPAGE_LIN
	jne   error
	mov   eax, TESTPAGE_PTE
	call  getPTE
	test  eax, PTE_ACCESSED|PTE_DIRTY ; A and D bits should be 0
	jnz   error
	test  ebx, PTE_PRESENT_BIT
	jz   .not_present
	test  ebx, PTE_USER_BIT
	jnz  .user
	jmp   error ; protection errors in supervisor mode can't happen
.not_present:
	setPTEFlag  TESTPAGE_PTE, PTE_PRESENT_BIT, PTE_PRESENT ; mark the PTE as present
	jmp  .check_rw
.user:
	setPTEFlag  TESTPAGE_PTE, PTE_USER_BIT, PTE_USER ; mark the PTE for user
.check_rw:
	test  ebx, PTE_WRITE_BIT
	jnz  .write
.read:
	mov   [TESTPAGE_OFF], dword PF_HANDLER_SIG ; put handler's signature in memory
	xor   eax, eax
	jmp  .exit
.write:
	setPTEFlag  TESTPAGE_PTE, PTE_WRITE_BIT, PTE_READWRITE ; mark the PTE for write
	mov   eax, PF_HANDLER_SIG ; put handler's signature in eax
.exit:
	iretd
