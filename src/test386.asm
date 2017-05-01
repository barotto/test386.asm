;
;   test386.asm
;   Copyright (C) 2012-2015 Jeff Parsons <Jeff@pcjs.org>
;   Copyright (C) 2017 Marco Bortolin <barotto@gmail.com>
;
;   This file is a derivative work of PCjs
;   http://pcjs.org/tests/pcx86/80386/test386.asm
;
;   test386.asm is free software: you can redistribute it and/or modify it under
;   the terms of the GNU General Public License as published by the Free
;   Software Foundation, either version 3 of the License, or (at your option)
;   any later version.
;
;   test386.asm is distributed in the hope that it will be useful, but WITHOUT ANY
;   WARRANTY without even the implied warranty of MERCHANTABILITY or FITNESS
;   FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;   details.
;
;   You should have received a copy of the GNU General Public License along with
;   test386.asm.  If not see <http://www.gnu.org/licenses/gpl.html>.
;
;   This program was originally developed for IBMulator
;   http://barotto.github.io/IBMulator
;
;   Overview
;   --------
;   This file is designed to run as a test ROM, loaded in place of the BIOS.
;   Its pourpose is to test the CPU, reporting its status to the POST port and
;   to the printer/serial port.
;   A 80386 or later CPU is required. This ROM is designed to test an emulator
;   CPU and was never tested on a real hardware.
;
;   It must be installed at physical address 0xf0000 and aliased at physical
;   address 0xffff0000.  The jump at resetVector should align with the CPU reset
;   address 0xfffffff0, which will transfer control to f000:0045.  From that
;   point on, all memory accesses should remain within the first 1MB.
;
%define COPYRIGHT 'test386.asm (C) 2012-2015 Jeff Parsons, (C) 2017 Marco Bortolin      '
%define RELEASE   '27/04/17'

	cpu 386
	section .text

	%include "x86_e.asm"

	bits 16

PAGING    equ 1
POST_PORT equ 0x190
LPT_PORT  equ 1
COM_PORT  equ 0
IBM_PS1   equ 1 ; this equ will enable the LPT port on the IBM PS/1 2011 and 2121

CSEG_REAL   equ 0xf000
CSEG_PROT16 equ 0x0008
CSEG_PROT32 equ 0x0010
DSEG_PROT16 equ 0x0018
DSEG_PROT32 equ 0x0020
SSEG_PROT32 equ 0x0028

OFF_ERROR   equ 0xc000

;
;   We set our exception handlers at fixed addresses to simplify interrupt gate descriptor initialization.
;
OFF_INTDEFAULT   equ OFF_ERROR
OFF_INTDIVERR    equ OFF_INTDEFAULT+0x200
OFF_INTPAGEFAULT equ OFF_INTDIVERR+0x200

;
;   Output a byte to the POST port, destroys al and dx
;
%macro POST 1
	mov al, 0x%1
	mov dx, POST_PORT
	out dx, al
%endmacro


header:
	db COPYRIGHT

cpuTest:
	cli


; ==============================================================================
;	Real mode tests
; ==============================================================================

;
;   Conditional jumps
;
%include "tests/jcc_m.asm"
	testJcc 8
	testJcc 16
	testJcc 32

;
;   Loops
;
%include "tests/loop_m.asm"
	testLoop
	testLoopZ
	testLoopNZ

;
;   Quick tests of unsigned 32-bit multiplication and division
;   Thorough arithmetical and logical tests are done later
;
	POST 1
	mov    eax, 0x80000001
	imul   eax
	mov    eax, 0x44332211
	mov    ebx, eax
	mov    ecx, 0x88776655
	mul    ecx
	div    ecx
	cmp    eax, ebx
	jne    error

;
;   Test of moving segment registers to 16/32-bit registers
;
%include "tests/mov_m.asm"

	POST 2
	testMovSegR ss
	testMovSegR ds
	testMovSegR es
	testMovSegR fs
	testMovSegR gs
;
;   Test store, move, scan, and compare string data in 16-bit real mode
;
%include "tests/string_m.asm"

	POST 3
	xor    dx, dx
	mov    ds, dx ; DS <- 0
	mov    es, dx ; ES <- 0
	mov    ecx, 0x1000
	mov    esi, 0
	mov    edi, 0x1000
	testStringOps b,0
	mov    ecx, 0x1000
	mov    esi, 0
	mov    edi, 0x2000
	testStringOps w,1
	mov    ecx, 0x1000
	mov    esi, 0
	mov    edi, 0x4000
	testStringOps d,2

;
;   Call real mode
;
%include "tests/call_m.asm"

	POST 4
	; initialize the stack
	mov ax, 0
	mov ss, ax
	mov sp, 0x8000
	mov si, 0
	testCallNear
	testCallFar CSEG_REAL



; ==============================================================================
;	Protected mode tests
; ==============================================================================

	jmp initPages

%include "protected_m.asm"

addrGDT:
	dw myGDTEnd - myGDT - 1 ; 16-bit limit of myGDT
	dw myGDT, 0x000f        ; 32-bit base address of myGDT

myGDT:
	defDesc NULL ; the first descriptor in any descriptor table is always a dud (it corresponds to the null selector)
	defDesc CSEG_PROT16,0x000f0000,0x0000ffff,ACC_TYPE_CODE_READABLE,EXT_NONE
	defDesc CSEG_PROT32,0x000f0000,0x0000ffff,ACC_TYPE_CODE_READABLE,EXT_BIG
	defDesc DSEG_PROT16,0x00000000,0x000fffff,ACC_TYPE_DATA_WRITABLE,EXT_NONE
	defDesc DSEG_PROT32,0x00000000,0x000fffff,ACC_TYPE_DATA_WRITABLE,EXT_BIG
	defDesc SSEG_PROT32,0x00010000,0x000effff,ACC_TYPE_DATA_WRITABLE,EXT_BIG
myGDTEnd:

addrIDT:
	dw myIDTEnd - myIDT - 1  ; 16-bit limit of myIDT
	dw myIDT, 0x000f         ; 32-bit base address of myIDT

myIDT:
	defGate CSEG_PROT32, OFF_INTDIVERR
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTPAGEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
myIDTEnd:

addrIDTReal:
	dw 0x3FF      ; 16-bit limit of real-mode IDT
	dd 0x00000000 ; 32-bit base address of real-mode IDT

initPages:
;
;   ESI (PDBR) = 1000h
;   00000-00FFF   1000 (4K)  free
;   01000-01FFF   1000 (4K)  page directory
;   02000-02FFF   1000 (4K)  page table
;   03000-10FFF   e000 (56K) stack tests
;   12000-12FFF   1000 (4K)  non present page (PTE 12h)
;   13000-9FFFF  8d000       free
;

PAGE_DIR_ADDR equ 0x1000
PAGE_TBL_ADDR equ 0x2000
NOT_PRESENT_PTE equ 0x12
NOT_PRESENT_LIN equ 0x12000
PF_HANDLER_SIG equ 0x50465046

;   Now we want to build a page directory and a page table. We need two pages of
;   4K-aligned physical memory.  We use a hard-coded address, segment 0x100,
;   corresponding to physical address 0x1000.
;
	POST 9
	mov   esi, PAGE_DIR_ADDR
	mov	  eax, esi
	shr   eax, 4
	mov   es,  eax
;
;   Build a page directory at ES:EDI (0100:0000) with only 1 valid PDE (the first one),
;   because we're not going to access any memory outside the first 1MB.
;
	cld
	mov   eax, PAGE_TBL_ADDR | PTE_USER | PTE_READWRITE | PTE_PRESENT
	xor   edi, edi
	stosd
	mov   ecx, 1024-1 ; ECX == number of (remaining) PDEs to write
	xor   eax, eax    ; fill remaining PDEs with 0
	rep   stosd
;
;   Build a page table at EDI with 256 (out of 1024) valid PTEs, mapping the first 1MB
;   as linear == physical.
;
	mov   eax, PTE_USER | PTE_READWRITE | PTE_PRESENT
	mov   ecx, 256 ; ECX == number of PTEs to write
initPT:
	stosd
	add   eax, 0x1000
	loop  initPT
	mov   ecx, 1024-256 ; ECX == number of (remaining) PTEs to write
	xor   eax, eax
	rep   stosd
	mov   edi, NOT_PRESENT_PTE ; mark PTE 12h (page at phy 12000h) as not present
	shl   edi, 2
	add   edi, PAGE_DIR_ADDR ; edi <- PAGE_DIR_ADDR + (NOT_PRESENT_PTE * 4)
	mov   eax, NOT_PRESENT_LIN | PTE_USER | PTE_READWRITE
	stosd
;
;   Enable protected mode
;
	cli ; make sure interrupts are off now, since we've not initialized the IDT yet
	o32 lidt [cs:addrIDT]
	o32 lgdt [cs:addrGDT]
	mov    cr3, esi
	mov    eax, cr0
	%if PAGING
	or     eax, CR0_MSW_PE | CR0_PG
	%else
	or     eax, CR0_MSW_PE
	%endif
	mov    cr0, eax
	jmp    CSEG_PROT32:toProt32 ; jump to flush the prefetch queue
toProt32:
	bits 32

;
;   Test the stack
;
	POST A
	mov    ax, DSEG_PROT16
	mov    ds, ax
	mov    es, ax
;
;   We'll set the top of our stack to ESI+0x2000+0xe000. This guarantees an ESP greater
;   than 0xffff, and so for the next few tests, with a 16-bit data segment in SS, we
;   expect all pushes/pops will occur at SP rather than ESP.
;
	add    esi, 0x2000       ; ESI <- PDBR + 0x2000, bottom of scratch memory
	mov    ss,  ax           ; SS <- DSEG_PROT16 (0x00000000 - 0x000fffff)
	lea    esp, [esi+0xe000] ; set ESP to bottom of scratch + 56K
	lea    ebp, [esp-4]
	and    ebp, 0xffff       ; EBP now mirrors SP instead of ESP
	mov    ebx, [ebp]        ; save dword about to be trashed by pushes
	mov    eax, 0x11223344
	push   eax
	cmp    [ebp], eax        ; did the push use SP instead of ESP?
	jne    error             ; no, error

	pop    eax
	push   ax
	cmp    [ebp+2], ax
	jne    error

	pop    ax
	mov    [ebp], ebx      ; restore dword trashed by the above pushes
	mov    ax,  DSEG_PROT32
	mov    ss,  ax
	lea    esp, [esi+0xe000] ; SS:ESP should now be a valid 32-bit pointer
	lea    ebp, [esp-4]
	mov    edx, [ebp]
	mov    eax, 0x11223344
	push   eax
	cmp    [ebp], eax  ; did the push use ESP instead of SP?
	jne    error       ; no, error

	pop    eax
	push   ax
	cmp    [ebp+2], ax
	jne    error
	pop    ax

;
;   Test moving a segment register to a 32-bit memory location
;
	POST B
	mov    ebx, [0x0000] ; save the DWORD at 0x0000:0x0000 in EBX
	or     eax, -1
	mov    [0x0000], eax
	mov    [0x0000], ds
	mov    ax, ds
	cmp    eax, [0x0000]
	jne    error

	mov    eax, ds
	xor    eax, 0xffff0000
	cmp    eax, [0x0000]
	jne    error

	mov    [0x0000], ebx ; restore the DWORD at 0x0000:0x0000 from EBX

;
;   Zero and sign-extension tests
;
	POST C
	movsx  eax, byte [cs:signedByte] ; byte to a 32-bit register with sign-extension
	cmp    eax, 0xffffff80
	jne    error

	movsx  eax, word [cs:signedWord] ; word to a 32-bit register with sign-extension
	cmp    eax, 0xffff8080
	jne    error

	movzx  eax, byte [cs:signedByte] ; byte to a 32-bit register with zero-extension
	cmp    eax, 0x00000080
	jne    error

	movzx  eax, word [cs:signedWord] ; word to a 32-bit register with zero-extension
	cmp    eax, 0x00008080
	jne    error

	mov    esp, 0x40000
	mov    edx, [esp]
	push   edx      ; save word at scratch address 0x40000
	add    esp, 4
	push   byte -128       ; NASM will not use opcode 0x6A ("PUSH imm8") unless we specify "byte"
	pop    ebx             ; verify EBX == 0xFFFFFF80
	cmp    ebx, 0xFFFFFF80
	jne    error

	and    ebx, 0xff       ; verify EBX == 0x00000080
	cmp    ebx, 0x00000080
	jne    error

	movsx  bx, bl          ; verify EBX == 0x0000FF80
	cmp    ebx, 0x0000FF80
	jne    error

	movsx  ebx, bx         ; verify EBX == 0xFFFFFF80
	cmp    ebx, 0xFFFFFF80
	jne    error

	movzx  bx,  bl         ; verify EBX == 0xFFFF0080
	cmp    ebx, 0xFFFF0080
	jne    error

	movzx  ebx, bl         ; verify EBX == 0x00000080
	cmp    ebx, 0x00000080
	jne    error

	not    ebx             ; verify EBX == 0xFFFFFF7F
	cmp    ebx,0xFFFFFF7F
	jne    error

	movsx  bx, bl          ; verify EBX == 0xFFFF007F
	cmp    ebx, 0xFFFF007F
	jne    error

	movsx  ebx, bl         ; verify EBX == 0x0000007F
	cmp    ebx, 0x0000007F
	jne    error

	not    ebx             ; verify EBX == 0xFFFFFF80
	cmp    ebx, 0xFFFFFF80
	jne    error

	movzx  ebx, bx         ; verify EBX == 0x0000FF80
	cmp    ebx, 0x0000FF80
	jne    error

	movzx  bx, bl          ; verify EBX == 0x00000080
	cmp    ebx,0x00000080
	jne    error

	movsx  bx, bl
	neg    bx
	neg    bx
	cmp    ebx, 0x0000FF80
	jne    error

	movsx  ebx, bx
	neg    ebx
	neg    ebx
	cmp    ebx, 0xFFFFFF80
	jne    error

;
;   Test 16-bit addressing modes
;
%include "tests/lea_m.asm"

	POST D
	mov ax, 0x0001
	mov bx, 0x0002
	mov cx, 0x0004
	mov dx, 0x0008
	mov si, 0x0010
	mov di, 0x0020
	testLEA16 [0x4000],0x4000
	testLEA16 [bx], 0x0002
	testLEA16 [si], 0x0010
	testLEA16 [di], 0x0020
	testLEA16 [bx + 0x40], 0x0042
	testLEA16 [si + 0x40], 0x0050
	testLEA16 [di + 0x40], 0x0060
	testLEA16 [bx + 0x4000], 0x4002
	testLEA16 [si + 0x4000], 0x4010
	testLEA16 [bx + si], 0x0012
	testLEA16 [bx + di], 0x0022
	testLEA16 [bx + 0x40 + si], 0x0052
	testLEA16 [bx + 0x40 + di], 0x0062
	testLEA16 [bx + 0x4000 + si], 0x4012
	testLEA16 [bx + 0x4000 + di], 0x4022

;
;   Test 32-bit addressing modes
;
	POST E
	mov eax, 0x0001
	mov ebx, 0x0002
	mov ecx, 0x0004
	mov edx, 0x0008
	mov esi, 0x0010
	mov edi, 0x0020
	testLEA32 [0x4000], 0x00004000
	testLEA32 [eax], 0x00000001
	testLEA32 [ebx], 0x00000002
	testLEA32 [ecx], 0x00000004
	testLEA32 [edx], 0x00000008
	testLEA32 [esi], 0x00000010
	testLEA32 [edi], 0x00000020
	testLEA32 [eax + 0x40], 0x00000041
	testLEA32 [ebx + 0x40], 0x00000042
	testLEA32 [ecx + 0x40], 0x00000044
	testLEA32 [edx + 0x40], 0x00000048
	testLEA32 [esi + 0x40], 0x00000050
	testLEA32 [edi + 0x40], 0x00000060
	testLEA32 [eax + 0x40000], 0x00040001
	testLEA32 [ebx + 0x40000], 0x00040002
	testLEA32 [ecx + 0x40000], 0x00040004
	testLEA32 [edx + 0x40000], 0x00040008
	testLEA32 [esi + 0x40000], 0x00040010
	testLEA32 [edi + 0x40000], 0x00040020
	testLEA32 [eax + ecx], 0x00000005
	testLEA32 [ebx + edx], 0x0000000a
	testLEA32 [ecx + ecx], 0x00000008
	testLEA32 [edx + ecx], 0x0000000c
	testLEA32 [esi + ecx], 0x00000014
	testLEA32 [edi + ecx], 0x00000024
	testLEA32 [eax + ecx + 0x40], 0x00000045
	testLEA32 [ebx + edx + 0x4000], 0x0000400a
	testLEA32 [ecx + ecx * 2], 0x0000000c
	testLEA32 [edx + ecx * 4], 0x00000018
	testLEA32 [esi + ecx * 8], 0x00000030
	testLEA32 [eax * 2], 0x00000002
	testLEA32 [ebx * 4], 0x00000008
	testLEA32 [ecx * 8], 0x00000020
	testLEA32 [0x40 + eax * 2], 0x00000042
	testLEA32 [0x40 + ebx * 4], 0x00000048
	testLEA32 [0x40 + ecx * 8], 0x00000060
	testLEA32 [ecx - 10 + ecx * 2], 0x00000002
	testLEA32 [edx - 10 + ecx * 4], 0x0000000e
	testLEA32 [esi - 10 + ecx * 8], 0x00000026
	testLEA32 [ecx + 0x40000 + ecx * 2], 0x0004000c
	testLEA32 [edx + 0x40000 + ecx * 4], 0x00040018
	testLEA32 [esi + 0x40000 + ecx * 8], 0x00040030

;
;   Access memory using various addressing modes
;
	POST F
	mov    ax, SSEG_PROT32  ; we want SS != DS for the next tests
	mov    ss, ax

	; store a known word at the scratch address
	mov    ebx, 0x11223344
	mov    [0x40000], ebx

	; now access that scratch address using various addressing modes
	mov    ecx, 0x40000
	cmp    [ecx], ebx
	jne    error

	add    ecx, 64
	cmp    [ecx-64], ebx
	jne    error

	sub    ecx, 64
	shr    ecx, 1
	cmp    [ecx+0x20000], ebx
	jne    error

	cmp    [ecx+ecx], ebx
	jne    error

	shr    ecx, 1
	cmp    [ecx+ecx*2+0x10000], ebx
	jne    error

	cmp    [ecx*4], ebx
	jne    error

	mov    ebp, ecx
	cmp    [ebp+ecx*2+0x10000], ebx
	je     error ; since SS != DS, this better be a mismatch

	pop    edx
	mov    [0x40000], edx ; restore word at scratch address 0x40000

;
;   Verify string operations
;
	POST 10
	pushad
	pushfd
	mov    ecx, 0x2000
	mov    esi, 0x13000
	mov    edi, 0x15000
	testStringOps b,0
	mov    ecx, 0x1000
	mov    esi, 0x13000
	mov    edi, 0x15000
	testStringOps w,1
	mov    ecx, 0x800
	mov    esi, 0x13000
	mov    edi, 0x15000
	testStringOps d,2
	popfd
	popad

;
;	Verify Page faults
;
	POST 11
	mov eax, [NOT_PRESENT_LIN] ; generate a page fault
	cmp eax, PF_HANDLER_SIG    ; the page fault handler should have put its signature in memory
	jne error

;
;   Verify Bit Scan operations
;
%include "tests/bit_m.asm"

	POST 12
	testBitscan bsf
	testBitscan bsr

;
;   Verify Bit Test operations
;
	POST 13
	testBittest bt

	testBittest btc
	cmp edx, 0x55555555
	jne error

	testBittest btr
	cmp edx, 0
	jne error

	testBittest bts
	cmp edx, 0xffffffff
	jne error

;
;   Test double precision shifts
;
	POST 14
	mov dword [0x40000], 0x0000a5a5
	mov ebx, 0x5a5a0000
	shld [0x40000], ebx, 16
	cmp dword [0x40000], 0xa5a55a5a
	jne error

	mov dword [0x40000], 0xa5a50000
	mov ebx, 0x00005a5a
	shrd [0x40000], ebx, 16
	cmp dword [0x40000], 0x5a5aa5a5
	jne error

;
;   SETcc - Byte set on condition
;
%include "tests/setcc_m.asm"

	POST 15
	testSetcc bl
	testSetcc byte [0x40000]


;
;	Call far protected mode
;
	POST 16
	testCallNear
	testCallFar CSEG_PROT32

;
;   Now run a series of unverified tests for arithmetical and logical opcodes
;   Manually verify by comparing the tests output with a reference file
;
	POST EE
	%if LPT_PORT && IBM_PS1
	; Enable output to the configured LPT port
	mov    ax, 0xff7f  ; bit 7 = 0  setup functions
	out    94h, al     ; system board enable/setup register
	mov    dx, 102h
	in     al, dx      ; al = p[102h] POS register 2
	or     al, 0x91    ; enable LPT1 on port 3BCh, normal mode
	out    dx, al
	mov    al, ah
	out    94h, al     ; bit 7 = 1  enable functions
	%endif
	jmp bcdTests

strEAX: db  "EAX=",0
strEDX: db  "EDX=",0
strPS:  db  "PS=",0
strDE:  db  "#DE ",0 ; when this is displayed, it indicates a Divide Error exception
achSize db  "BWD"
%include "print_p.asm"

bcdTests:
%include "tests/bcd_m.asm"
    testBCD   daa, 0x12340503, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340506, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340507, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340559, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340560, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x1234059f, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x123405a0, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340503, 0,             PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340506, 0,             PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340503, PS_CF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340506, PS_CF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340503, PS_CF | PS_AF, PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   daa, 0x12340506, PS_CF | PS_AF, PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340503, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340506, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340507, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340559, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340560, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x1234059f, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x123405a0, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340503, 0,             PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340506, 0,             PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340503, PS_CF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340506, PS_CF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340503, PS_CF | PS_AF, PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   das, 0x12340506, PS_CF | PS_AF, PS_CF | PS_PF | PS_ZF | PS_SF | PS_AF
    testBCD   aaa, 0x12340205, PS_AF,         PS_CF | PS_AF
    testBCD   aaa, 0x12340306, PS_AF,         PS_CF | PS_AF
    testBCD   aaa, 0x1234040a, PS_AF,         PS_CF | PS_AF
    testBCD   aaa, 0x123405fa, PS_AF,         PS_CF | PS_AF
    testBCD   aaa, 0x12340205, 0,             PS_CF | PS_AF
    testBCD   aaa, 0x12340306, 0,             PS_CF | PS_AF
    testBCD   aaa, 0x1234040a, 0,             PS_CF | PS_AF
    testBCD   aaa, 0x123405fa, 0,             PS_CF | PS_AF
    testBCD   aas, 0x12340205, PS_AF,         PS_CF | PS_AF
    testBCD   aas, 0x12340306, PS_AF,         PS_CF | PS_AF
    testBCD   aas, 0x1234040a, PS_AF,         PS_CF | PS_AF
    testBCD   aas, 0x123405fa, PS_AF,         PS_CF | PS_AF
    testBCD   aas, 0x12340205, 0,             PS_CF | PS_AF
    testBCD   aas, 0x12340306, 0,             PS_CF | PS_AF
    testBCD   aas, 0x1234040a, 0,             PS_CF | PS_AF
    testBCD   aas, 0x123405fa, 0,             PS_CF | PS_AF
    testBCD   aam, 0x12340547, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_OF | PS_AF
    testBCD   aad, 0x12340407, PS_AF,         PS_CF | PS_PF | PS_ZF | PS_SF | PS_OF | PS_AF

arithlogicTests:
	cld
	mov    esi, tableOps   ; ESI -> tableOps entry

testOps:
	movzx  ecx, byte [cs:esi]           ; ECX == length of instruction sequence
	test   ecx, ecx                     ; (must use JZ since there's no long version of JECXZ)
	jz     near testDone                ; zero means we've reached the end of the table
	movzx  ebx, byte [cs:esi+1]         ; EBX == TYPE
	shl    ebx, 6                       ; EBX == TYPE * 64
	movzx  edx, byte [cs:esi+2]         ; EDX == SIZE
	shl    edx, 4                       ; EDX == SIZE * 16
	lea    ebx, [cs:typeValues+ebx+edx] ; EBX -> values for type
	add    esi, 3                       ; ESI -> instruction mnemonic
.skip:
	cs lodsb
	test   al,al
	jnz    .skip
	push   ecx
	mov    ecx, [cs:ebx]    ; ECX == count of values for dst
	mov    eax, [cs:ebx+4]  ; EAX -> values for dst
	mov    ebp, [cs:ebx+8]  ; EBP == count of values for src
	mov    edi, [cs:ebx+12] ; EDI -> values for src
	xchg   ebx, eax         ; EBX -> values for dst
	sub    eax, eax         ; set all ARITH flags to known values prior to tests
testDst:
	push   ebp
	push   edi
	pushfd
testSrc:
	mov   eax, [cs:ebx]    ; EAX == dst
	mov   edx, [cs:edi]    ; EDX == src
	popfd
	call  printOp
	call  printEAX
	call  printEDX
	call  printPS
	call  esi       ; execute the instruction sequence
	call  printEAX
	call  printEDX
	call  printPS
	call  printEOL
	pushfd
	add   edi,4    ; EDI -> next src
	dec   ebp      ; decrement src count
	jnz   testSrc
	popfd
	pop   edi         ; ESI -> restored values for src
	pop   ebp         ; EBP == restored count of values for src
	lea   ebx,[ebx+4] ; EBX -> next dst (without modifying flags)
	loop  testDst

	pop  ecx
	add  esi, ecx     ; ESI -> next tableOps entry
	jmp  testOps

testDone:
	jmp testsDone

%include "tests/arith-logic_d.asm"

	times	OFF_ERROR-($-$$) nop

error:
	cli
	hlt
	jmp error

	times OFF_INTDIVERR-($-$$) nop

intDivErr:
	push esi
	mov  esi,strDE
	call printStr
	pop  esi
;
;   It's rather annoying that the 80386 treats #DE as a fault rather than a trap, leaving CS:EIP pointing to the
;   faulting instruction instead of the RET we conveniently placed after it.  So, instead of trying to calculate where
;   that RET is, we simply set EIP on the stack to point to our own RET.
;
	mov  dword [esp], intDivRet
	iretd
intDivRet:
	ret

	times OFF_INTPAGEFAULT-($-$$) nop

intPageFault:
	; check the error code, it must be 0
	pop   eax
	cmp   eax, 0
	jnz error
	; check CR2 register, it must contain the linear address NOT_PRESENT_LIN
	mov   eax, cr2
	cmp   eax, NOT_PRESENT_LIN
	jne   error
	; mark the PTE as present
	mov   bx, ds ; save DS
	mov   ax, DSEG_PROT16
	mov   ds, ax
	mov   eax, NOT_PRESENT_PTE ; mark PTE as present
	shl   eax, 2
	add   eax, PAGE_TBL_ADDR ; eax <- PAGE_DIR_ADDR + (NOT_PRESENT_PTE * 4)
	mov   edx, [eax]
	or    edx, PTE_PRESENT
	mov   [eax], edx
	mov   eax, PAGE_DIR_ADDR
	mov   cr3, eax ; flush the page translation cache
	; mark the memory location at NOT_PRESENT_LIN with the handler signature
	mov   eax, PF_HANDLER_SIG
	mov   [NOT_PRESENT_LIN], eax
	mov   ds, bx ; restore DS
	xor   eax, eax
	iretd

LPTports:
	dw   0x3BC
	dw   0x378
	dw   0x278
COMTHRports:
	dw   0x3F8
	dw   0x2F8
COMLSRports:
	dw   0x3FD
	dw   0x2FD
signedWord:
	db   0x80
signedByte:
	db   0x80

testsDone:
;
; Testing finished, back to real mode and prepare to restart
;
	POST FF
	mov  ax,  DSEG_PROT16
	mov  ss,  ax
	sub  esp, esp
;
;   Return to real-mode, after first resetting the IDTR and loading CS with a 16-bit code segment
;
	o32 lidt [cs:addrIDTReal]
	jmp  CSEG_PROT16:toProt16
toProt16:
	bits 16
goReal:
	mov    eax, cr0
	and    eax, ~(CR0_MSW_PE | CR0_PG) & 0xffffffff
	mov    cr0, eax
jmpReal:
	jmp    CSEG_REAL:toReal
toReal:
	mov    ax, cs
	mov    ds, ax
	mov    es, ax
	mov    ss, ax
	mov    sp, 0xfffe
	cli
	hlt
;
;   Fill the remaining space with NOPs until we get to target offset 0xFFF0.
;
	times 0xfff0-($-$$) nop

resetVector:
	jmp   CSEG_REAL:cpuTest ; 0000FFF0

release:
	db    RELEASE,0       ; 0000FFF5  release date
	db    0xFC            ; 0000FFFE  FC (Model ID byte)
	db    0x00            ; 0000FFFF  00 (checksum byte, unused)
