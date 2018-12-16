;  Executable name : base32enc
;  Version         : 1.0
;  Created date    : 11/8/2018
;  Last update     : 11/10/2018
;  Author          : Sam Imboden
;  Description     : Base32 encoding
;
;  Run it this way:
;    base32enc < (input file)  
;
;  Build using these commands:
;    nasm -f elf64 -g -F dwarf base32enc.asm
;    ld -o base32enc base32enc.o
;
;
;For permission to use/copy/sell this software contact Sam Imboden (imboden dot sam at gmail dot com).

SECTION .data			; Section containing initialised data
	
	Convert_Table: db "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567="
	CT_Len: equ $-Convert_Table	
	NewLine: db 10
	
SECTION .bss			; Section containing uninitialized data

	BUFFLEN	equ 5		; We read the file 16 bytes at a time
	Buff: 	resb BUFFLEN	; Text buffer itself
	BUFFBLEN equ 8
	BuffB: resb BUFFBLEN
	BuffW: resb 1
	
		
SECTION .text			; Section containing code

global 	_start			; Linker needs this to find the entry point!
	
_start:
	nop			; This no-op keeps gdb happy...
	mov rax, BuffB
	 mov r15, 0
; Read a buffer full of text from stdin:
Read:   
    xor rax, rax
    mov qword [Buff], rax
	mov eax,3		    ; Specify sys_read call
	mov ebx,0		    ; Specify File Descriptor 0: Standard Input
	mov ecx,Buff		; Pass offset of the buffer to read to
	mov edx,BUFFLEN		; Pass number of bytes to read at one pass
	int 80h			    ; Call sys_read to fill the buffer
	mov ebp,eax		    ; Save # of bytes read from file for later
	cmp eax,0		    ; If eax=0, sys_read reached EOF on stdin
	je Done			    ; Jump If Equal (to 0, from compare)
	
	cmp ebp, 5          ; If 5 bytes
	je five_pack
	
	cmp ebp, 5          ; If less than 5 bytes
	jb not_five_pack
	

Done:
	mov eax,1		    ; Code for Exit Syscall
	mov ebx,0		    ; Return a code of zero	
	int 80H			    ; Make kernel call


Write:
    mov rdi, 0
    write_byte:                    ; Write the line of hexadecimal values to stdout:
        cmp r15, 76
        je newline
        mov byte al, [BuffB+rdi]
        mov byte [BuffW], al
        mov eax,4		    ; Specify sys_write call
        mov ebx,1		    ; Specify File Descriptor 1: Standard output
        mov ecx,BuffW		; Pass offset of line string
        mov edx,1	; Pass size of the line string
        int 80h			    ; Make kernel call to display line string
        inc r15
        inc rdi
        cmp rdi, 8
        jb write_byte

	
	jmp Read		    ; Loop back and load file buffer again
	
newline:
        mov eax,4		    ; Specify sys_write call
        mov ebx,1		    ; Specify File Descriptor 1: Standard output
        mov ecx, NewLine
        mov edx,1	; Pass size of the line string
        int 80h			    ; Make kernel call to display line string
        mov r15, 0
        cmp rdi, 8
        jb write_byte
jmp Read

five_pack:;Shifting Byte for Byte from Buff into RAX
    xor rax, rax        ;delete rax
    mov byte al,[Buff]  ;Get byte from buffer
    shl rax, 8          ;make space for next byte
    mov byte al,[Buff+1];read next byte
    shl rax, 8
    mov byte al,[Buff+2]
    shl rax, 8
    mov byte al,[Buff+3]
    shl rax, 8
    mov byte al,[Buff+4]
jmp Write_toBuffB_ALL

not_five_pack:
    mov ecx, 0
    xor rbx, rbx
    
    readbyte:           ; Read all Bytes that are left in buffer
        shl rbx, 8
        mov byte bl,[Buff+ecx]
        inc cx
        dec ebp
        jnz readbyte
                        ;Calculate how many Zeros nedded to be added for a Five Pack
    mov rcx, 8
    mul rcx
    mov rcx, 5
    xor rdx,rdx
    div rcx
    mov r8, 5
    sub r8, rdx
    mov r9, r8
                        ;Add zeros
    Shift:
        shl rbx, 1
        dec r8
        jnz Shift
    inc rax
                        ;Calculate how many equives it needs
    mov r12, 8
    sub r12, rax
                        ;Calcualte how many Zeros it needs for getting 40 Bits in rbx
    mov r9, rax
    mov rcx, 5
    mul rcx
    mov r8, rax
    mov rax, 40
    sub rax, r8
                        ;Fills rbx with zeros until 40 bits
    Filler:
        shl rbx,1
        dec rax
        jnz Filler
    mov rax, rbx
    
jmp Write_toBuffB

Convert_toBase:
    mov rcx, 0
    BaseCnvtr:
        xor rax, rax                            ;delete rax
        xor rbx, rbx                            ;delete rbx
        mov byte al, [BuffB+rcx]                ;Get number from BufferB which is also the index for the Converting Table
        mov byte bl, [Convert_Table+rax]        ; add convertet number to bl
        mov byte [BuffB+rcx], bl                ; Replace number in buffer
        inc rcx                                 ; convert next slot
        cmp rcx, 8
        jb BaseCnvtr        
jmp Write

Write_toBuffB:
                        ;Loops did not work, maybe in V2, V1 is hardcoded
    xor rbx,rbx
    mov r11, 8
    sub r11, r12        ; Get the number of bytes needed to be convertet
    mov qword [BuffB], rbx ; delete Buffer for safety reasons
                        ;Could be shorter with loop but shl and shr don't want to work with 2 registers
    mov rbx, rax        ;Move rax to rbx for masking
    mov rcx, 0x1F       ;Bitmask
    shl rcx, 35
    and rbx, rcx
    shr rbx, 35
    mov byte [BuffB], bl
    dec r11
    
    shr rcx, 5          ;shift mask back
    mov rbx, rax
    and rbx, rcx
    shr rbx, 30         ;Shift result back so its only a byte
    cmp r11, 1          ;if r11 below 1 it's time to add equives
    jb e1
    buff1:  mov byte [BuffB+1], bl      ;Add masked and shiftet result into buffer
            dec r11     ;Decrement r11 so we know whne to add equives
            jmp next1
    e1:     mov byte [BuffB+1], 0x20    ;Add 32 to buffer eg the equive
    next1:
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 25
    cmp r11, 1
    jb e2
    buff2:  mov byte [BuffB+2], bl
            dec r11
            jmp next2
    e2:     mov byte [BuffB+2], 0x20 
     next2:
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 20
    cmp r11, 1
    jb e3
    buff3:  mov byte [BuffB+3], bl
            dec r11
            jmp next3
    e3:     mov byte [BuffB+3], 0x20 
     next3:
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 15
    cmp r11, 1
    jb e4
    buff4:  mov byte [BuffB+4], bl
            dec r11
            jmp next4
    e4:     mov byte [BuffB+4], 0x20 
     next4:

    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 10
    cmp r11, 1
    jb e5
    buff5:  mov byte [BuffB+5], bl
            dec r11
            jmp next5
    e5:     mov byte [BuffB+5], 0x20        
    next5:
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 5
    cmp r11, 1
    jb e6
    buff6:  mov byte [BuffB+6], bl
            dec r11
            jmp next6
    e6:     mov byte [BuffB+6], 0x20   
    next6:
    
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    cmp r11, 1
    jb e7
    buff7:  mov byte [BuffB+7], bl
            jmp next7
    e7:     mov byte [BuffB+7], 0x20  
    next7:
jmp Convert_toBase

Write_toBuffB_ALL:
   
    xor rbx,rbx
;     mov qword [BuffB], rbx  ;Delete BufferB for safety reasons
                        ;Could be shorter with loop but shl and shr don't want to work with 2 registers
    mov rbx, rax        ;Move rax to rbx for masking
    mov rcx, 0x1F       ;move mask to rcx
    shl rcx, 35         ;shit mask to right place
    and rbx, rcx        ;Apply mask
    shr rbx, 35         ;Shift result back so it's only one byte
    mov byte [BuffB], bl;Add byte to BufferB
    ;The same again and aigain...
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 30
    mov byte [BuffB+1], bl
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 25
    mov byte [BuffB+2], bl
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 20
    mov byte [BuffB+3], bl
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 15
    mov byte [BuffB+4], bl

    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 10
    mov byte [BuffB+5], bl
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    shr rbx, 5
    mov byte [BuffB+6], bl
    
    shr rcx, 5
    mov rbx, rax
    and rbx, rcx
    mov byte [BuffB+7], bl
jmp Convert_toBase





















