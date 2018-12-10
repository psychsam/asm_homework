;  Executable name : base32dec
;  Version         : 1.0
;  Created date    : 18/12/2018
;  Last update     : 18/12/2018
;  Author          : Sam Imboden
;  Description     : A simple program in assembly for Linux, using NASM 2.05,
; 		     Decoding a base32 file.
;
;  Run it this way:
;    base32dec < (input file)  
;
;  Build using these commands:
;    nasm -f elf64 -g -F dwarf base32dec.asm
;    ld -o base32dec base32dec.o
;
;
;For permission to use/copy/sell this software contact Sam Imboden (imboden dot sam at gmail dot com).

SECTION .data			; Section containing initialised data
	
	Convert_Table: db "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567="
	CT_Len: equ $-Convert_Table	
	
SECTION .bss			; Section containing uninitialized data

	BUFFLEN	equ 8		; We read the file 16 bytes at a time
	Buff: 	resb BUFFLEN	; Text buffer itself
	BUFFBLEN equ 5
	BuffB: resb BUFFBLEN
	BUFFRLEN equ 1
	BuffR: resb BUFFRLEN
		
SECTION .text			; Section containing code

global 	_start			; Linker needs this to find the entry point!
	
_start:
	nop			; This no-op keeps gdb happy...
	mov r15, 0
	mov rax, Buff
; Read a buffer full of text from stdin:
Read:
    xor rax, rax
	mov eax,3		    ; Specify sys_read call
	mov ebx,0		    ; Specify File Descriptor 0: Standard Input
	mov ecx,BuffR		; Pass offset of the buffer to read to
	mov edx,BUFFRLEN		; Pass number of bytes to read at one pass
	int 80h			    ; Call sys_read to fill the buffer
	mov ebp,eax		    ; Save # of bytes read from file for later
	cmp eax,0		    ; If eax=0, sys_read reached EOF on stdin
	je Done			    ; Jump If Equal (to 0, from compare)
	
	jmp Read_eight
	
Done:
	mov eax,1		    ; Code for Exit Syscall
	mov ebx,0		    ; Return a code of zero	
	int 80H			    ; Make kernel call


Write:
                        ; Write the line of hexadecimal values to stdout:
	mov eax,4		    ; Specify sys_write call
	mov ebx,1		    ; Specify File Descriptor 1: Standard output
	mov ecx,BuffB		; Pass offset of line string
    ;mov edx,edx	; Pass size of the line string
	int 80h			    ; Make kernel call to display line string
	
	jmp Read		    ; Loop back and load file buffer again

Read_eight:
mov byte al, [BuffR]
cmp al, 0x0a
je Read
mov byte [Buff+r15], al
inc r15
cmp r15, 8
jne Read
mov r15, 0

Convert_back:
	;variable initializing
	mov r8, 0
	mov r10, 0      ; Storage for # equives
	mov rcx, 0       ; Adress offset
	mov rdx, 0x20    ; Converting Table offset also the convertet number
	xor rax, rax
	xor rbx, rbx
	xor rcx, rcx
	
	;procedure
	next: mov byte al, [Buff+rcx]; Move buffer byte to al
		mov byte bl, [Convert_Table+rdx]; Move Converting table char to bl
		cmp al, bl              ; Compare if char is same
		jne next_step           ; If not goto next step
		cmp dl, 0x20            ; If char is equive
		jne not_equiv           ; If not skip increment
		inc r10                 ; Increment equive counter
		not_equiv: 
		mov byte [Buff+r8], dl  ; Replace current buffer byte with actual value
		inc r8
		mov dl, 0               ; Next char
		next_step: dec dl ; Decrement adress from converting table
		cmp dl, 255         ; Check if al chars got compared
		jb next              ; if not jump up
		mov rdx, 0x20	  ; Converting Table offset also the convertet number
		inc rcx            ; if true increment buffer offset
		cmp ecx, 8         ; Check if all buffer bytes got convertet
	jb next           ; If not jump up
	;end of convertion
jmp eight_to_fife


eight_to_fife:
	;variable initializing
	mov rcx, 8
	mov rax, 0
	mov rdx, 0
	;procedure
	sub rcx, r10 ;Get amount of packages
	get_byte: 
		mov rbx, 0 ; reset rbx just to be sure
		mov byte bl, [Buff+rdx]; get byte
		shl rax, 5 ; make space for new number
		or rax, rbx; add number
		inc rdx; incr step
		cmp rdx, rcx ; if not done make again
	jne get_byte
	mov rdx, 4 ; buff offset (for later, is for eight_)
	mov rbx, 5 ; How many packages for the write procedure, needed to set here because it might get changed below
	cmp r10, 0 ; when no equives skip next operation
	je eight_ ; Here is the calculation for the amount of backshifting eg delete zeros that are added from the encoding (multiplikatives inversum)
		mov rbx, rax ; copy rax to rbx because we need rax for mul operation
		mov rax, 5; Number of bit per pack
		mul rcx ; Multiply numbers of packs to get numbers of bits
		mov rdx, 0; set to zero
		mov rcx, 8; mov divider
		div rcx; divide this is to get the integral
		mov cl, dl; get modulo result
		mov rdx, rax; the result of division is the numbers of bytes to write
		mov rax, rbx; move rbx back to rax
		shr rax, cl ; shift with cl (whhhyy only cl. whhhhyyyyy)
		mov rbx, rdx ; copy number of bytes for writing out
		dec rdx; decrement rdx because it starts with zero

eight_:
	;procedure
	copy_to_buff:
		mov byte [BuffB+rdx], al
		shr rax, 8
		dec rdx
		cmp rdx, 255
	jb copy_to_buff
	mov rdx, rbx
jmp Write
