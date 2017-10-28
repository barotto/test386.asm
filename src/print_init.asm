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
