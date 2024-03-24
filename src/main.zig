// возможности языка: переменные, операции, циклы, ветвления

const std = @import("std");
const print = std.debug.print;

const flags = struct { perem: bool, code: bool, loop: bool, is_branch: bool, brackets: u32 };
const CompileError = error{SyntaxError};

pub fn main() !void {
    // const t = try read_file();
    // print("{s}", .{t});

    const string = "let var1 = 100\nlet var2 = 10\nlet var3 = 0\nif var3 == 0\n{\nvar3 = var3 + var2\n}\nwhile var1 < 10\n{\nprint var1\nvar1 = var1 - 1\n}\n";

    const lines = try trim_str(string, '\n');

    // var status = flags{
    //     .perem = false,
    //     .code = false,
    //     .loop = false,
    //     .is_branch = false,
    //     .brackets = 0,
    // };

    const allocator = std.heap.page_allocator;

    var final_code = std.ArrayList([]const u8).init(allocator);
    defer final_code.deinit();
    try final_code.append(".global main\n");

    var block_map = std.AutoHashMap(usize, @TypeOf(final_code)).init(allocator);
    defer block_map.deinit();

    try block_map.put(0, final_code);

    for (lines) |line| {
        const tokens = try trim_str(line, ' ');

        if (in_str(tokens[0], "let") and tokens[0].len == 3) {
            try final_code.append(line[4..]);
            try final_code.append("\n");
        }
    }

    // for (lines) |line| {
    //     const tokens = try trim_str(line, ' ');
    //     print("{s} || {any}\n", .{ tokens, in_str(tokens[0], "let") });
    //     if (in_str(tokens[0], "let")) {
    //         if (!status.perem) {
    //             status.perem = true;
    //             try final_code.append(".data");
    //             try final_code.append("\n");
    //         }
    //         try final_code.append(line[4..]);
    //         try final_code.append("\n");
    //     } else if (!status.code) {
    //         status.code = true;
    //         try final_code.append("main:\n");
    //     } else if (in_str(tokens[0], "if")) {
    //         // TODO
    //         // версия с одним условием
    //         // доделать преобразование условий для сложных выражений
    //         try final_code.append("cmp ");
    //         try final_code.append(tokens[1]);
    //         try final_code.append(",");
    //         try final_code.append(tokens[3]);
    //         try final_code.append("\n");
    //         if (in_str(tokens[2], "==")) {
    //             try final_code.append("je ");
    //         } else if (in_str(tokens[2], ">=")) {
    //             try final_code.append("\n");
    //         } else if (in_str(tokens[2], "<=")) {
    //             try final_code.append("\n");
    //         } else if (in_str(tokens[2], ">")) {
    //             try final_code.append("\n");
    //         } else if (in_str(tokens[2], "<")) {
    //             try final_code.append("\n");
    //         } else if (in_str(tokens[2], "!=")) {
    //             try final_code.append("jne ");
    //         }
    //         try final_code.append("else\n");
    //     } else if (in_str(line, "else")) {
    //         try final_code.append("else:\n"); // записать блок с +1 brackets
    //     } else if (in_str(line, "{")) {
    //         status.brackets += 1;
    //     } else if (in_str(line, "{")) {
    //         status.brackets -= 1;
    //         try final_code.append("main:\n");
    //     }
    // }

    print("\n\n", .{});
    for (final_code.items) |str| {
        print("{s}", .{str});
    }
}

pub fn in_str(str1: []const u8, str2: []const u8) bool {
    if (str1.len < str2.len) {
        return false;
    }
    var trust = true;
    for (0..(str1.len - str2.len)) |i| {
        const a = str1[i .. str2.len + i];
        const b = str2;
        for (a, b) |char1, char2| {
            if (char1 != char2) {
                trust = false;
                break;
            }
        }
        if (trust) {
            return trust;
        }
    }
    return trust;
}

pub fn trim_str(str: anytype, delim: u8) ![][]const u8 {
    var v = std.ArrayList([]const u8).init(std.heap.page_allocator);
    var i: usize = 0;
    for (str, 0..) |char, j| {
        if (char == delim) {
            try v.append(str[i..j]);
            // print("{s}\t", .{str[i..j]});
            // print("{}, {}\n", .{ i, j });
            i = j + 1;
        }
    }
    if (delim != '\n') {
        try v.append(str[i..str.len]);
    }
    return v.items;
    // print("{any}", .{v});
}
