;
; 16-bit TSS execution path, in parallel with test386.asm tests running in 386 mode
;

ptrTSSprot32Gate: ; pointer to the 32-bit task state segment gate
	dd 0
	dw TSS_GSEG_PROT32|3

BITS 32
errorTSS16:
	mov ax,SU_SEG_PROT16SS|3              ;SS OK?
	mov ss,ax                             ;Fixup SS
	mov esp,(ESP_R3_PROT|0xFFFF0000)      ;Fixup SP
	jmp error                             ;Error out!

TSS286entrypoint:
	cmp esp,0xFFFF1122         ;SP loaded correctly?
	jnz errorTSS16
	mov sp,ESP_R3_PROT     ;Fixup SP
	cmp eax,0xFFFF1234         ;EAX loaded correctly?
	jnz errorTSS16
	cmp ecx,0xFFFF5678
	jnz errorTSS16
	cmp edx,0xFFFF9ABC
	jnz errorTSS16
	cmp ebx,0xFFFFDEF0
	jnz errorTSS16
	cmp ebp,0xFFFF3344
	jnz errorTSS16
	cmp esi,0xFFFF5566
	jnz errorTSS16
	cmp edi,0xFFFF7788
	jnz errorTSS16
	;General purpose registers are loaded OK. Now check the segment registers.
	pushfd
	pop eax
	and eax,0x4000  ;Make sure that the flags are properly tested.
	cmp eax,0x4000 ;Flags OK?
	jnz errorTSS16_1
	mov ax,ss
	cmp ax,SU_SEG_PROT16SS|3  ;SS OK?
	jnz errorTSS16_1
	mov ax,cs
	cmp ax,CU_SEG_PROT16CS|3  ;CS OK?
	jnz errorTSS16_1
	mov ax,ds
	cmp ax,SU_SEG_PROT16DS|3  ;DS OK?
	jnz errorTSS16_1
	mov ax,es
	cmp ax,SU_SEG_PROT16ES|3  ;ES OK?
	jnz errorTSS16_1
	mov ax,fs
	cmp ax,0                  ;FS OK?
	jnz errorTSS16_1
	mov ax,gs
	cmp ax,0                  ;GS OK?
	jnz errorTSS16_1
	sldt ax
	cmp ax,LDT_SEG_PROT286    ;LDT OK?
	jnz errorTSS16_1
	iret                    ;Return to the calling task
	jmp TSS1_returned
errorTSS16_1: ;Error occurred?
	jmp error
;We return here after check #1.
TSS1_returned:
	;Now we start our TSS flags test
	pushfd
	pop eax
	test ax,PS_NT         ;Task properly nested?
	jz error
	push dword (FLAGS_SET|PS_NT)
	popfd    ;Set the flags to test.
	iret                   ;return to the calling 32-bit task
	;Now the flags should have been set.
	pushfd
	pop eax
	cmp eax,dword (FLAGS_SET|PS_NT) ;Correct?
	jnz errorTSS16_1
	push dword (FLAGS_CLEARED|PS_NT)
	popfd ;Clear the flags to test
	iret                   ;return to the calling 32-bit task
	pushfd
	pop eax
	cmp eax,dword (FLAGS_SET|PS_NT) ;Correct?
	iret                   ;return to the calling 32-bit task
	
	;Now, we switched sides to test.
	;Test the flags register during task switches now.
	int 0x29 ;Start testing the 386 flags
	push dword FLAGS_CLEARED
	popfd    ;Clear the flags to test.
	int 0x29 ;Continue testing the 386 flags
	push dword FLAGS_SET
	popfd    ;Set the flags to test.
	int 0x29 ;Third stage of the flags test.
	;386 flags test completed.

	;Now, we switch sides
	jmp far [cs:ptrTSSprot32Gate]

	;We've been far called. Return.
	iretd

	;We're the parent task again.
	call far [cs:ptrTSSprot32Gate]
	;Now, we switch sides
	jmp far [cs:ptrTSSprot32Gate]