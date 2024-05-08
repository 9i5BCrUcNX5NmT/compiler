global _start
extern _print
section .data
a dq 0
d dq 0
section .text
_start:
push 1234567890
pop qword[a]
loop1:
push 0
push 2
push qword[a]
pop rax
cqo
pop r9
idiv r9
push rdx
pop r8
pop r9
cmp r8, r9
je pos1
push 0
jmp neg1
pos1:
push 1
neg1:
pop r8
cmp r8, 0
jne start2
jmp end2
start2:
push 2
push qword[a]
pop rax
cqo
pop r9
idiv r9
push rax
pop r8
mov qword[a], r8
push 2
pop r15
call _print
jmp loop1
end2:
push 3
pop qword[d]
loop3:
push 1
push qword[a]
pop r8
pop r9
cmp r8, r9
ja pos3
push 0
jmp neg3
pos3:
push 1
neg3:
pop r8
cmp r8, 0
jne start4
jmp end4
start4:
loop4:
push 0
push qword[d]
push qword[a]
pop rax
cqo
pop r9
idiv r9
push rdx
pop r8
pop r9
cmp r8, r9
je pos4
push 0
jmp neg4
pos4:
push 1
neg4:
pop r8
cmp r8, 0
jne start5
jmp end5
start5:
push qword[d]
push qword[a]
pop rax
cqo
pop r9
idiv r9
push rax
pop r8
mov qword[a], r8
push qword[d]
pop r15
call _print
jmp loop4
end5:
push 2
push qword[d]
pop r8
pop r9
add r8, r9
push r8
pop r8
mov qword[d], r8
jmp loop3
end4:
push qword[a]
pop r15
call _print
exit:
mov rax, 60
syscall
