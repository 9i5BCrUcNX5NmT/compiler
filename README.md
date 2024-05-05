## Псевдо компилятор условного языка в nasm
### Синтаксис
a = 1
нет ';' в конце выражения

(a + b)
Пробелы между переменными и операторами обязательны

if (a > b)
{
a = 1
}
{} - всегда на отдельной строчке
после if выражение, выполнение {} если его результат != 0

while a < b
{
a = a - 1
}
аналогично для while
### Run
#### 1
в начальной папке:
```
zig build run
```
(depend on zig)
#### 2
в папке asm:
```
./run.sh output
```
(depend on nasm)