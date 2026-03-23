;
; 16-bit TSS execution path, in parallel with test386.asm tests running in 386 mode
;
errorTSS16:
	mov ax,SU_SEG_PROT16SS|3 ;SS OK?
	mov ss,ax                ;Fixup SS
	mov esp,ESP_R3_PROT      ;Fixup SP
	jmp error                ;Error out!

TSS286entrypoint:
	jnc errorTSS16         ;eflags loaded incorrectly?
	mov [0], eax
	lahf
	mov byte [4],ah        ;Store the flags for checking later
	mov eax,[0]
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
	movzx eax,byte [4]   ;Validate the flags
	sahf                 ;Restore the original flags of the task
	pushfd
	and word [esp],0x40FF  ;Make sure that the flags are properly tested.
	pop eax
	cmp eax,0x4003 ;Flags OK?
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
	clc
	iret                    ;Return to the calling task
	jmp TSS1_returned
errorTSS16_1: ;Error occurred?
	jmp error
;We return here after check #1.
TSS1_returned:
	jc errorTSS16_1        ;flags register not loaded correctly if carry is set
	iret                   ;return to the calling 32-bit task