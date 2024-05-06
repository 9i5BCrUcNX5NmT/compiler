global _start
extern _print
section .data
c dq 0
b dq 0
a dq 0
section .text
_start:
push 1
pop qword[c]
push 1
pop qword[b]
push 1
pop qword[a]
push qword[c]
push qword[b]
push qword[a]
pop r8
pop r9
imul r8, r9
push r8
pop r8
pop r9
add r8, r9
push r8
pop r8
mov qword[a], r8
push qword[a]
pop r15
call _print
exit:
mov rax, 60
syscall
pos:
push 1
ret
neg:
push 0
ret
