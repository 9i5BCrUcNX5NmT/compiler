// возможности языка: переменные, операции, циклы, ветвления

const std = @import("std");
const print = std.debug.print;

comptime {
    asm (
    // \\.global my_func;
    // \\.def my_func; .scl 2; .type 32; .endef
    // \\my_func:
    // \\  lea (4), %eax
    // \\  retq
        \\.global main;
        \\.data
        \\  var1 = 100
        \\  var2 = 10
        \\  var3 = var1 * var2
        \\main:
        \\  mov %eax, var1
        \\  call while
        \\  mov var1, %eax
        \\
        \\while:
        \\  cmp %eax, 10
        \\  jnl while_end
        \\  add %eax, 1
        \\while_end:
        \\  ret
    );
}

pub fn main() !void {
    try read_file();
    // const string = "var1 = 100;\nvar2 = 10;\nvar3 = var1 * var2;\nwhile var1 < 10\n{\nprint var1;\nvar = var - 1;\n}\n";

    // inline for (string) |char| {
    //     print("{c}", .{char});
    // }

    // print("\n\n", .{});
    // const tokens = try trim_str(string);
    // print("{s}", .{tokens});

    // Do magic
    // 0) начало кода
    // .global main
    // .data
    // [name] = [?] | [int] | [expression]
    // 1) выделить память для var1
    // 2) записать туда 100
    // var1 = 100
    // 3) повторить для var2
    // var2 = 10
    // 4) повторить для var3
    // var3 = var1 * var2
    // 5) создаём цикл
    //  -- помещаем в регистры переменные
    //  while усл -> .name: \n действия \n усл -> cmp \n jl | jnl \n [ret?] \n
    //  -- возвращаем переменные из регистров
    // 6) if
    //  -- помещаем в регистры переменные
    //  if -> .name: \n усл -> cmp \n jnl \n действия \n [ret?] \n
    //  -- возвращаем переменные из регистров
}

pub fn read_file() !void {
    var file = try std.fs.cwd().openFile("C:\\Users\\misha\\Dev\\zig\\code", .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\r')) |line| {
        // do something with line...
        print("{s} ----------", .{line});
    }
}

pub fn trim_str(str: anytype) ![][]const u8 {
    var v = std.ArrayList([]const u8).init(std.heap.page_allocator);
    var i: usize = 0;
    inline for (str, 0..) |char, j| {
        if (char == ' ' or char == '\n') {
            try v.append(str[i..j]);
            // print("{s}\t", .{str[i..j]});
            // print("{}, {}\n", .{ i, j });
            i = j + 1;
        }
    }
    return v.items;
    // print("{any}", .{v});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
