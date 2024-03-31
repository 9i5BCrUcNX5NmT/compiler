// возможности языка: переменные, операции, циклы, ветвления

const std = @import("std");
const print = std.debug.print;
// const eql = std.mem.eql;

const lib = @import("root.zig");

// const flags = struct { brackets: u32 };
const CompileError = error{ SyntaxError, ShadowingVariable, NedopisanCod };

pub fn main() !void {
    // const path_to_code = "code"; // путь к файлу с кодом
    // const code = @embedFile(path_to_code);
    const allocator = std.heap.page_allocator;

    // const lines = try trim_str(code, "\n");

    // for (lines) |value| {
    //     print("{s}\n", .{value});
    // }

    const expr = "var1 = -1 + var3 * (a - t)";
    var tree = lib.Tree([]const u8).init(allocator);
    try tree.pull_tree(expr);
    tree.print_tree();
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
