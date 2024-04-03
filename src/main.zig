// возможности языка: переменные, операции, циклы, ветвления
// TODO:
//  - обработка любых выражений +
//  - if / while утверждения =
//  - инициализация переменных =
//  ! перевод в asm -
//  ! обработка выхода дерева -

const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;

const Tree = @import("root.zig").Tree;

// const flags = struct { brackets: u32 };
const CompileError = error{ SyntaxError, ShadowingVariable, NedopisanCod };
const allocator = std.heap.page_allocator;
const var_type = "dq";

pub fn main() !void {
    const path_to_code = "code"; // путь к файлу с кодом
    const code = @embedFile(path_to_code);
    // const code = "let a = 1\nlet b = 2\nlet c = 3\nlet var1 = 0\nvar1 = c - (a + b) \n";

    var lines = std.mem.tokenize(u8, code, "\n");
    var all = std.ArrayList([]const u8).init(allocator);
    defer all.deinit();
    var data = std.ArrayList([]const u8).init(allocator);
    defer data.deinit();
    var normal = std.ArrayList([]const u8).init(allocator);
    defer normal.deinit();

    try all.append("global _start\n");
    try data.append("section .data\n");
    try normal.append("_start:\n");

    // генерация без if и while
    while (lines.next()) |line| {
        if (eql(u8, line[0..3], "let")) {
            var tokens = std.mem.tokenize(u8, line[4..], " ");
            const var_name = tokens.next().?;

            try data.append(var_name);
            try data.append(" ");
            try data.append(var_type);
            try data.append(" 0");
            try data.append("\n");

            try compute_expr(&normal, line[4..]);
        } else {
            try compute_expr(&normal, line);
        }
    }

    try conctenate(&all, &data);
    try all.append("section .text\n");
    try conctenate(&all, &normal);
    try all.append("exit:\nmov rax, 60\nsyscall\n");

    for (all.items) |value| {
        print("{s}", .{value});
    }

    // for (lines) |value| {
    //     print("{s}\n", .{value});
    // }

    // const expr = "var1 = 1";

    // var tree = Tree([]const u8).init(allocator);
    // defer tree.deinit();

    // try tree.pull_tree(expr);
    // try tree.gen_output();

    // for (tree.output.items) |value| {
    //     print("{s}", .{value});
    // }
}

fn conctenate(out: *std.ArrayList([]const u8), in: *std.ArrayList([]const u8)) !void {
    for (in.items) |value| {
        try out.append(value);
    }
}

fn compute_expr(block: *std.ArrayList([]const u8), line: []const u8) !void {
    var tree = Tree([]const u8).init(allocator);
    defer tree.deinit();

    try tree.pull_tree(line);
    try tree.gen_output();

    for (tree.output.items) |value| {
        try block.append(value);
    }
}

// pub fn in_str(str1: []const u8, str2: []const u8) bool {
//     if (str1.len < str2.len) {
//         return false;
//     }
//     var trust = true;
//     for (0..(str1.len - str2.len)) |i| {
//         const a = str1[i .. str2.len + i];
//         const b = str2;
//         for (a, b) |char1, char2| {
//             if (char1 != char2) {
//                 trust = false;
//                 break;
//             }
//         }
//         if (trust) {
//             return trust;
//         }
//     }
//     return trust;
// }

// pub fn what_jump_are_you(token: []const u8) []const u8 {
//     if (eql(u8, token, ">")) {
//         return "ja";
//     } else if (eql(u8, token, "<")) {
//         return "jl";
//     } else if (eql(u8, token, "==")) {
//         return "je";
//     } else if (eql(u8, token, ">=")) {
//         return "jge";
//     } else if (eql(u8, token, "<=")) {
//         return "jle";
//     } else if (eql(u8, token, "!=")) {
//         return "jne";
//     }
//     return "jmp";
// }

// pub fn trim_str(str: anytype, delim: []const u8) ![][]const u8 {
//     const allocator = std.heap.page_allocator;
//     var lines = std.ArrayList([]const u8).init(allocator);
//     var readIter = std.mem.tokenize(u8, str, delim);
//     while (readIter.next()) |line| {
//         var readIter = std.mem.tokenize(
//             u8,
//             str,
//         );
//         try lines.append(line);
//     }
//     return lines.items;
// }
