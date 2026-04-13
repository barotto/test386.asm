; ValidateTSSbusy: Validate the busy bit of a TSS
; Parameters:
; %1 TSS descriptor to validate.
; %2 expected B-bit
%macro validateTSSbusy286 2
	mov eax,(%1 | (%2<<16))
	o32 call far [cs:ptrTSSprot32validatebusy]
%endmacro
%macro validateTSSbusy386 2
	mov eax,(%1 | (%2<<16))
	o32 call far [cs:ptrTSSprot32validatebusy+0xE0000]
%endmacro


; ValidateTSSbacklink: Validate the backlink of a TSS
; Parameters:
; %1 TSS data descriptor to validate.
; %2 expected backlink
%macro validateTSSbacklink286 2
	mov eax,(%1 | (%2<<16))
	o32 call far [cs:ptrTSSprot32validatebacklink]
%endmacro
%macro validateTSSbacklink386 2
	mov eax,(%1 | (%2<<16))
	o32 call far [cs:ptrTSSprot32validatebacklink+0xE0000]
%endmacro

; Setbacklink: Validate the backlink of a TSS
; Parameters:
; %1 TSS data descriptor to validate.
; %2 backlink to set
%macro setTSSbacklink286 2
	mov eax,(%1 | (%2<<16))
	o32 call far [cs:ptrTSSprot32setbacklink]
%endmacro
%macro setTSSbacklink386 2
	mov eax,(%1 | (%2<<16))
	o32 call far [cs:ptrTSSprot32setbacklink+0xE0000]
%endmacro

; validateTSSNT: Validate the NT bit of a TSS
; Parameters:
; %1 TSS data descriptor to validate. 0 for current task.
; %2 TSS size (0 for 16-bit, 1 for 32-bit)
; %3 NT bit to validate
%macro validateTSSNT286 3
	mov eax,(%1 | ((%3|(%2<<1))<<16))
	o32 call far [cs:ptrTSSprot32validateNT]
%endmacro
%macro validateTSSNT386 3
	mov eax,(%1 | ((%3|(%2<<1))<<16))
	o32 call far [cs:ptrTSSprot32validateNT+0xE0000]
%endmacro

; setNTflag: Set the NT bit of the current TSS
; Parameters:
; %1 selector of TSS to use. 0 for current task FLAGS register.
; %2 TSS size (0 for 16-bit, 1 for 32-bit)
; %3 NT bit to set
%macro setNTflag286 3
	mov eax,(%1 | ((%3|(%2<<1))<<16))
	o32 call far [cs:ptrTSSprot32setNT]
%endmacro
%macro setNTflag386 3
	mov eax,(%1 | ((%3|(%2<<1))<<16))
	o32 call far [cs:ptrTSSprot32setNT+0xE0000]
%endmacro

%macro validateTSandClear 1
	mov eax,%1
	int 0x2C ;Validate and clear TS bit.
%endmacro
