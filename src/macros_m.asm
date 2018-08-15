;
;   Output a byte to the POST port, destroys al and dx
;
%macro POST 1
	mov al, 0x%1
	mov dx, POST_PORT
	out dx, al
%endmacro

;
; Initializes an interrupt gate in system memory.
; This is the body of procedures used in 16 and 32-bit code segments.
;
; EAX vector
; ECX offset
; DS:EBX pointer to IDT
;
%macro initIntGateMem 0
	shl    eax, 3
	add    ebx, eax
	mov    word [ebx], cx
	mov    dx, C_SEG_PROT32
	mov    word [ebx+2], dx
	mov    word [ebx+4], ACC_TYPE_GATE386_INT | ACC_PRESENT
	shr    ecx, 16
	mov    word [ebx+6], cx
%endmacro

;
; Initializes a code/data segment in system memory.
; This is the body of procedures used in 16 and 32-bit code segments.
;
;    7                             0 7                             0
;   ╔═══════════════════════════════╤═══╤═══╤═══╤═══╤═══════════════╗
; +7║            BASE 31-24         │ G │B/D│ 0 │AVL│  LIMIT 19-16  ║+6
;   ╟───┬───────┬───┬───────────┬───┼───┴───┴───┴───┴───┴───┴───┴───╢
; +5║ P │  DPL  │ 1 │   TYPE    │ A │          BASE 23-16           ║+4
;   ╟───┴───┴───┴───┴───┴───┴───┴───┴───────────────────────────────╢
; +3║                           BASE 15-0                           ║+2
;   ╟───────────────────────────────┴───────────────────────────────╢
; +1║                           LIMIT 15-0                          ║ 0
;   ╚═══════════════════════════════╧═══════════════════════════════╝
;    15                                                            0
;
; DS:EBX pointer to the descriptor table
; EAX segment selector
; ESI base
; EDI limit
; DL ext nibble (upper 4 bits)
; DH acc byte (P|DPL|1|TYPE|A)
;
%macro initSegDescMem 0
	and    eax, 0xFFF8
	add    ebx, eax
	mov    word [ebx], di   ; LIMIT 15-0
	mov    word [ebx+2], si ; BASE 15-0
	shr    esi, 16
	mov    ax, si           ; AX := BASE 31-16
	mov    byte [ebx+4], al ; BASE 23-16
	mov    byte [ebx+5], dh ; acc byte
	shr    edi, 16
	mov    cx, di
	and    cl, 0x0f
	mov    byte [ebx+6], cl ; LIMIT 19-16
	and    dl, 0xf0
	or     byte [ebx+6], dl ; ext nibble
	mov    byte [ebx+7], ah ; BASE 31-24
%endmacro


%macro advTestBase 0
	%assign TEST_BASE1 TEST_BASE1+0x1000
	%assign TEST_BASE2 TEST_BASE2+0x1000
%endmacro
