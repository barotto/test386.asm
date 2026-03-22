;
; 16-bit TSS execution path, in parallel with test386.asm tests running in 386 mode
;
errorTSS16:
	mov ax,SU_SEG_PROT16SS ;SS OK?
	mov ss,ax              ;Fixup SS
	mov esp,ESP_R3_PROT    ;Fixup SP
	jmp error              ;Error out!

TSS286entrypoint:
	jnc errorTSS16         ;eflags loaded incorrectly?
	cmp esp,0x1122         ;SP loaded correctly?
	jnz errorTSS16
	mov sp,ESP_R3_PROT     ;Fixup SP
	cmp eax,0x1234         ;EAX loaded correctly?
	jnz errorTSS16
	cmp ecx,0x5678
	jnz errorTSS16
	cmp edx,0x9ABC
	jnz errorTSS16
	cmp ebx,0xDEF0
	jnz errorTSS16
	cmp ebp,0x3344
	jnz errorTSS16
	cmp esi,0x5566
	jnz errorTSS16
	cmp edi,0x7788
	jnz errorTSS16
	;General purpose registers are loaded OK. Now check the segment registers.
	pushfd
	pop eax   ;Validate the flags
	cmp eax,2 ;Flags OK?
	jnz errorTSS16_1
	mov ax,ss
	cmp ax,SU_SEG_PROT16SS  ;SS OK?
	jnz errorTSS16_1
	mov ax,cs
	cmp ax,CU_SEG_PROT16CS	;CS OK?
	jnz errorTSS16_1
	mov ax,ds
	cmp ax,SU_SEG_PROT16DS  ;DS OK?
	jnz errorTSS16_1
	mov ax,es
	cmp ax,SU_SEG_PROT16ES  ;ES OK?
	jnz errorTSS16_1
	mov ax,fs
	cmp ax,0                ;FS OK?
	jnz errorTSS16_1
	mov ax,gs
	cmp ax,0                ;GS OK?
	jnz errorTSS16_1
	clc
	iret                    ;Return to the calling task
	jmp TSS1_returned
errorTSS16_1: ;Error occurred?
	jmp error
;We return here after check #1.
TSS1_returned:
	jc errorTSS16_1        ;flags register not loaded correctly if carry is set
	iret                   ;return to the calling 32-bit task