;
;   test386.asm
;   Copyright (C) 2012-2015 Jeff Parsons <Jeff@pcjs.org>
;   Copyright (C) 2017-2018 Marco Bortolin <barotto@gmail.com>
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
%define COPYRIGHT 'test386.asm (C) 2012-2015 Jeff Parsons, (C) 2017-2018 Marco Bortolin '
%define RELEASE   '??/??/18'

	cpu 386
	section .text

	%include "x86_e.asm"

	bits 16

; ==============================================================================
;   CONFIGURATION
;
;   If your system needs a specific LPT or COM initialization procedure put it
;   inside the print_init.asm file.
;
; ==============================================================================
POST_PORT  equ 0x190 ; hex, the diagnostic port used to emit the current test procedure
LPT_PORT   equ 1     ; integer, parallel port to use, 0=LPT disabled, 1=3BCh, 2=378h, 3=278h
COM_PORT   equ 0     ; integer, serial port to use, 0=COM disabled, 1=3F8h-3FDh, 2=2F8h-2FDh
OUT_PORT   equ 0x0   ; hex, additional port for direct ASCII output, 0=disabled
TEST_UNDEF equ 0     ; boolean, enable undefined behaviours tests
CPU_FAMILY equ 3     ; integer, used to test undefined behaviours, 3=80386
IBM_PS1    equ 0     ; boolean, enable specific code for the IBM PS/1 2011 and 2121 models
BOCHS      equ 0     ; boolean, enable compatibility with the Bochs x86 PC emulator
;
; == END OF CONFIGURATION ======================================================
;


;
;   Code and data segments
;
CSEG_REAL   equ 0xf000
CSEG_PROT16 equ 0x0008
CSEG_PROT32 equ 0x0010
DSEG_PROT16 equ 0x0018
DSEG_PROT32 equ 0x0020
SSEG_PROT32 equ 0x0028
DSEG_PROT16RO equ 0x0030


;
;   We set our exception handlers at fixed addresses to simplify interrupt gate descriptor initialization.
;
OFF_ERROR        equ 0xc000
OFF_INTDEFAULT   equ OFF_ERROR
OFF_INTDIVERR    equ OFF_INTDEFAULT+0x200
OFF_INTPAGEFAULT equ OFF_INTDIVERR+0x200
OFF_INTBOUND     equ OFF_INTPAGEFAULT+0x200
OFF_INTGP        equ OFF_INTBOUND+0x200


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

	POST 0
;
;   Conditional jumps
;
%include "tests/jcc_m.asm"
	testJcc 8
	testJcc 16

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
	testCallNear sp
	testCallFar CSEG_REAL

;
;   Load full pointer
;
%include "tests/load_ptr_m.asm"
	POST 5
	mov di, 0
	testLoadPtr ss
	testLoadPtr ds
	testLoadPtr es
	testLoadPtr fs
	testLoadPtr gs


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
	defDesc DSEG_PROT16RO,0x00000000,0x000fffff,ACC_TYPE_DATA_READABLE,EXT_NONE
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
	defGate CSEG_PROT32, OFF_INTBOUND
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTDEFAULT
	defGate CSEG_PROT32, OFF_INTGP
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
;   03000-11FFF   f000 (60K) free
;   12000-12FFF   1000 (4K)  non present page (PTE 12h)
;   13000-9FFFF  8d000       free
;

PAGE_DIR_ADDR equ 0x1000
PAGE_TBL_ADDR equ 0x2000
NOT_PRESENT_PTE equ 0x12
NOT_PRESENT_LIN equ 0x12000
GP_HANDLER_SIG equ 0x47504841
PF_HANDLER_SIG equ 0x50465046
BOUND_HANDLER_SIG equ 0x626f756e

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
	or     eax, CR0_MSW_PE | CR0_PG
	mov    cr0, eax
	jmp    CSEG_PROT32:toProt32 ; jump to flush the prefetch queue
toProt32:
	bits 32

;
;   Test the stack
;
%include "tests/stack_m.asm"

	POST A
;
;   For the next tests, with a 16-bit data segment in SS, we
;   expect all pushes/pops will occur at SP rather than ESP.
;
	mov    ax, DSEG_PROT16
	mov    ds, ax
	mov    es, ax
	mov    ss, ax

	testPushPopR ax,16
	testPushPopR bx,16
	testPushPopR cx,16
	testPushPopR dx,16
	testPushPopR sp,16
	testPushPopR bp,16
	testPushPopR si,16
	testPushPopR di,16
;
;   Now use a 32-bit stack address size.
;   All pushes/pops will occur at ESP rather than SP.
;
	mov    ax,  DSEG_PROT32
	mov    ss,  ax

	testPushPopR ax,32
	testPushPopR bx,32
	testPushPopR cx,32
	testPushPopR dx,32
	testPushPopR bp,32
	testPushPopR sp,32
	testPushPopR si,32
	testPushPopR di,32

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
;	Verify page faults and memory access rights
;
	POST 11
	mov eax, [NOT_PRESENT_LIN] ; generate a page fault
	cmp eax, PF_HANDLER_SIG    ; the page fault handler should have put its signature in memory
	jne error
	mov ax, DSEG_PROT16RO
	mov ds, ax              ; write protect DS
	xor eax, eax
	mov byte [0x40000], 0   ; generate #GP
	cmp eax, GP_HANDLER_SIG ; see if #GP handler was called
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
	testBittest16 bt
	testBittest16 btc
	cmp edx, 0x00005555
	jne error
	testBittest16 btr
	cmp edx, 0
	jne error
	testBittest16 bts
	cmp edx, 0x0000ffff
	jne error

	testBittest32 bt
	testBittest32 btc
	cmp edx, 0x55555555
	jne error
	testBittest32 btr
	cmp edx, 0
	jne error
	testBittest32 bts
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
;	Call protected mode
;
	POST 16
	mov esp, 0x10000
	mov si, 0xf000
	testCallNear esp
	testCallFar CSEG_PROT32

;
;	ARPL
;
	POST 17
	; test on register destination
	xor ax, ax       ; ZF = 0
	mov ax, 0xfff0
	mov bx, 0x0002
	arpl ax, bx      ; RPL ax < RPL bx
	jnz error        ; must be ZF = 1
	cmp ax, 0xfff2
	jne error
	; test on memory destination
	xor ax, ax       ; ZF = 0
	mov word [0x40000], 0xfff0
	arpl [0x40000], bx
	jnz error
	cmp word [0x40000], 0xfff2
	jne error
	%if BOCHS = 0
	; test unexpected memory write
	;
	; This test fails with Bochs, which does not write to memory (correctly),
	; but throws a #GP fault before that, during the reading of the memory
	; operand. Bochs checks that the destination segment is writeable before the
	; execution of ARPL.
	;
	mov ax, DSEG_PROT16RO   ; make DS read only
	mov ds, ax
	xor eax, eax
	arpl [0x40000], bx      ; value has not changed, arpl should not write to memory
	cmp eax, GP_HANDLER_SIG ; test if #GP handler was called
	je error
	mov ax, DSEG_PROT16     ; make DS writeable again
	mov ds, ax
	%endif
	; test with RPL dest > RPL src
	xor ax, ax       ; ZF = 0
	mov ax, 0xfff3
	arpl ax, bx
	jz error
	cmp ax, 0xfff3
	jne error

;
;	BOUND
;
	POST 18
	xor eax, eax
	mov ebx, 0x10100
	mov word [0x40000], 0x0010
	mov word [0x40002], 0x0102
	o16 bound bx, [0x40000]
	cmp eax, BOUND_HANDLER_SIG
	je error
	mov word [0x40002], 0x00FF
	o16 bound bx, [0x40000]
	cmp eax, BOUND_HANDLER_SIG
	jne error
	xor eax, eax
	mov dword [0x40004], 0x10010
	mov dword [0x40008], 0x10102
	o32 bound ebx, [0x40004]
	cmp eax, BOUND_HANDLER_SIG
	je error
	mov dword [0x40008], 0x100FF
	o32 bound ebx, [0x40004]
	cmp eax, BOUND_HANDLER_SIG
	jne error


%include "print_init.asm"

	jmp undefTests

%include "print_p.asm"

;
;   Undefined behaviours and bugs
;   Results have been validated against 386SX hardware.
;
undefTests:

	POST E0

	mov al, 0
	cmp al, TEST_UNDEF
	je arithLogicTests

	mov al, CPU_FAMILY
	cmp al, 3
	je bcd386FlagsTest
	call printUnkCPU
	jmp error

	%include "tests/bcd_m.asm"

bcd386FlagsTest:
	PS_CAO  equ PS_CF|PS_AF|PS_OF
	PS_PZSO equ PS_PF|PS_ZF|PS_SF|PS_OF

	; AAA
	; undefined flags: PF, ZF, SF, OF
	testBCDflags   aaa, 0x0000, 0,           PS_PF|PS_ZF
	testBCDflags   aaa, 0x0001, PS_PZSO,     0
	testBCDflags   aaa, 0x007A, 0,           PS_CF|PS_AF|PS_SF|PS_OF
	testBCDflags   aaa, 0x007B, PS_AF,       PS_CF|PS_PF|PS_AF|PS_SF|PS_OF
	; AAD
	; undefined flags: CF, AF, OF
	testBCDflags   aad, 0x0001, PS_CAO,      0
	testBCDflags   aad, 0x0D8E, 0,           PS_CAO
	testBCDflags   aad, 0x0106, 0,           PS_AF
	testBCDflags   aad, 0x01F7, 0,           PS_CF|PS_AF
	; AAM
	; undefined flags: CF, AF, OF
	testBCDflags   aam, 0x0000, 0,           PS_ZF|PS_PF
	testBCDflags   aam, 0x0000, PS_CAO,      PS_ZF|PS_PF
	; AAS
	; undefined flags: PF, ZF, SF, OF
	testBCDflags   aas, 0x0000, PS_SF|PS_OF, PS_PF|PS_ZF
	testBCDflags   aas, 0x0000, PS_AF,       PS_CF|PS_PF|PS_AF|PS_SF
	testBCDflags   aas, 0x0001, PS_PZSO,     0
	testBCDflags   aas, 0x0680, PS_AF,       PS_CF|PS_AF|PS_OF
	; DAA
	; undefined flags: OF
	testBCDflags   daa, 0x001A, PS_AF|PS_OF, PS_AF
	testBCDflags   daa, 0x001A, PS_CF,       PS_CF|PS_AF|PS_SF|PS_OF
	; DAS
	; undefined flags: OF
	testBCDflags   das, 0x0080, PS_OF,       PS_SF
	testBCDflags   das, 0x0080, PS_AF,       PS_AF|PS_OF

shifts386FlagsTest:
	%include "tests/shift_m.asm"

	; SHR al,cl - SHR ax,cl
	; undefined flags:
	;  CF when cl>7 (byte) or cl>15 (word):
	;    if byte operand and cl=8 or cl=16 or cl=24 then CF=MSB(operand)
	;    if word operand and cl=16 then CF=MSB(operand)
	;  OF when cl>1: set according to result
	;  AF when cl>0: always 1
	; shift count is modulo 32 so if cl=32 then result is equal to cl=0
	testShiftBFlags   shr, 0x81,   1,  0,     PS_CF|PS_AF|PS_OF
	testShiftBFlags   shr, 0x82,   2,  0,     PS_CF|PS_AF
	testShiftBFlags   shr, 0x80,   8,  0,     PS_CF|PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shr, 0x00,   8,  PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shr, 0x80,   16, 0,     PS_CF|PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shr, 0x00,   16, PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shr, 0x80,   24, 0,     PS_CF|PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shr, 0x00,   24, PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shr, 0x80,   32, 0,     0
	testShiftWFlags   shr, 0x8000, 16, 0,     PS_CF|PS_PF|PS_AF|PS_ZF
	testShiftWFlags   shr, 0x0000, 16, PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftWFlags   shr, 0x8000, 32, 0,     0

	; SHL al,cl - SHL ax,cl
	; undefined flags:
	;  CF when cl>7 (byte) or cl>15 (word):
	;    if byte operand and cl=8 or cl=16 or cl=24 then CF=LSB(operand)
	;    if word operand and cl=16 then CF=LSB(operand)
	;  OF when cl>1: set according to result
	;  AF when cl>0: always 1
	; shift count is modulo 32 so if cl=32 then result is equal to cl=0
	testShiftBFlags   shl, 0x81, 1,  0,     PS_CF|PS_AF|PS_OF
	testShiftBFlags   shl, 0x41, 2,  0,     PS_CF|PS_AF|PS_OF
	testShiftBFlags   shl, 0x01, 8,  0,     PS_CF|PS_PF|PS_AF|PS_ZF|PS_OF
	testShiftBFlags   shl, 0x00, 8,  PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shl, 0x01, 16, 0,     PS_CF|PS_PF|PS_AF|PS_ZF|PS_OF
	testShiftBFlags   shl, 0x00, 16, PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shl, 0x01, 24, 0,     PS_CF|PS_PF|PS_AF|PS_ZF|PS_OF
	testShiftBFlags   shl, 0x00, 24, PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftBFlags   shl, 0x01, 32, 0,     0
	testShiftWFlags   shl, 0x01, 16, 0,     PS_CF|PS_PF|PS_AF|PS_ZF|PS_OF
	testShiftWFlags   shl, 0x00, 16, PS_CF, PS_PF|PS_AF|PS_ZF
	testShiftWFlags   shl, 0x01, 32, 0,     0

bt386FlagsTest:
	; BT, BTC, BTR, BTS
	; undefined flags:
	;  OF: same as RCR with CF=0
	testBittestFlags   0x01, 0, 0,     PS_CF
	testBittestFlags   0x01, 0, PS_CF, PS_CF
	testBittestFlags   0x01, 1, 0,     PS_OF
	testBittestFlags   0x01, 1, PS_CF, PS_OF
	testBittestFlags   0x01, 2, 0,     PS_OF
	testBittestFlags   0x01, 2, PS_CF, PS_OF
	testBittestFlags   0x01, 3, 0,     0
	testBittestFlags   0x01, 3, PS_CF, 0

rotate386FlagsTest:
	; RCR
	; CF and OF are set with byte and count=9 or word and count=17
	testShiftBFlags   rcr, 0,    9, 0,           0
	testShiftBFlags   rcr, 0,    9, PS_CF|PS_OF, PS_CF
	testShiftBFlags   rcr, 0x40, 9, 0,           PS_OF
	testShiftBFlags   rcr, 0x40, 9, PS_CF|PS_OF, PS_CF|PS_OF
	testShiftWFlags   rcr, 0,      17, 0,           0
	testShiftWFlags   rcr, 0,      17, PS_CF|PS_OF, PS_CF
	testShiftWFlags   rcr, 0x4000, 17, 0,           PS_OF
	testShiftWFlags   rcr, 0x4000, 17, PS_CF|PS_OF, PS_CF|PS_OF
	; RCL
	; CF and OF are set with byte and count=9 or word and count=17
	testShiftBFlags   rcl, 0,    9, 0,           0
	testShiftBFlags   rcl, 0,    9, PS_CF|PS_OF, PS_CF|PS_OF
	testShiftBFlags   rcl, 0x80, 9, 0,           PS_OF
	testShiftBFlags   rcl, 0x80, 9, PS_CF|PS_OF, PS_CF
	testShiftWFlags   rcl, 0,      17, 0,           0
	testShiftWFlags   rcl, 0,      17, PS_CF|PS_OF, PS_CF|PS_OF
	testShiftWFlags   rcl, 0x8000, 17, 0,           PS_OF
	testShiftWFlags   rcl, 0x8000, 17, PS_CF|PS_OF, PS_CF

	jmp arithLogicTests


;
;   Now run a series of unverified tests for arithmetical and logical opcodes
;   Manually verify by comparing the tests output with a reference file
;
arithLogicTests:

	POST EE

	jmp bcdTests


bcdTests:
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
	testBCD   aam, 0x12340547, PS_AF,         PS_PF | PS_ZF | PS_SF
	testBCD   aad, 0x12340407, PS_AF,         PS_PF | PS_ZF | PS_SF

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

	times OFF_INTBOUND-($-$$) nop

intBound:
	mov word [0x40002], 0x0100
	mov dword [0x40008], 0x10100
	mov eax, BOUND_HANDLER_SIG
	iretd

	times OFF_INTGP-($-$$) nop

intGeneralProtection:
	pop eax ; pop the error code
	mov ax, ds
	cmp ax, DSEG_PROT16RO ; see if this handler was called for a write on RO segment
	jne error
	mov ax, DSEG_PROT16
	mov ds, ax
	mov eax, GP_HANDLER_SIG
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
