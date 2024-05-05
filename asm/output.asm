global _start
extern _print
section .data
a dq 0
section .text
_start:
push 5
pop qword[a]
push 5
push 100
pop r8
pop r9
imul r8, r9
push r8
push qword[a]
pop r8
pop r9
add r8, r9
push r8
pop r15
call _print
exit:
mov rax, 60
syscall
