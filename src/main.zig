// возможности языка: переменные, операции, циклы, ветвления
// TODO:
//  - обработка любых выражений +
//  - инициализация переменных +
//  ! перевод в asm:
//      - (+,-,/,%,*) +
//      - if / while -
//  ! обработка выхода дерева -

const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;

const Tree = @import("root.zig").Tree;

// const flags = struct { brackets: u32 };
const CompileError = error{ SyntaxError, ShadowingVariable, NedopisanCod };
const allocator = std.heap.page_allocator;
const var_type = "dq";
const delim: std.mem.DelimiterType = .any;

pub fn main() !void {
    const path_to_code = "code"; // путь к файлу с кодом
    const code = @embedFile(path_to_code);
    // const code = "let a = 1\nlet b = 2\nlet c = 3\nlet var1 = 0\nvar1 = c - (a + b) \n";

    var vars = std.StringHashMap(bool).init(allocator);
    defer vars.deinit();

    var lines = std.mem.tokenize(u8, code, "\n");

    var all = std.ArrayList([]const u8).init(allocator);
    defer all.deinit();
    var data = std.ArrayList([]const u8).init(allocator);
    defer data.deinit();
    var normal = std.ArrayList([]const u8).init(allocator);
    defer normal.deinit();

    try all.append("global _start\n");
    try all.append("extern _print\n");
    try data.append("section .data\n");
    try normal.append("_start:\n");

    // var loop_id = lines.rest().len;
    while (lines.next()) |line| {
        var tokens = std.mem.tokenize(u8, line, " ");
        const first = tokens.next().?;
        var var_name: []const u8 = undefined;

        if (eql(u8, first, "{")) {
            try normal.append("l1:\n");
        } else if (eql(u8, first, "}")) {
            try normal.append("l2:\n");
        } else if (!eql(u8, first, "if") and !eql(u8, first, "while")) {
            var_name = first;
            _ = tokens.next().?; // = TODO может быть ошибка если нет равно в выражении

            if (!vars.contains(var_name)) {
                // print("\n-------------\n", .{});
                try vars.put(var_name, true); // добавлени в спиисок переменных

                try data.append(var_name);
                try data.append(" ");
                try data.append(var_type);
                try data.append(" 0\n");
            }
            try var_expr(var_name, &tokens, &normal, &vars);
        } else if (eql(u8, first, "if")) {
            // TODO cmp
            try var_expr(var_name, &tokens, &normal, &vars);
            try normal.append("pop\n");
            try normal.append("jne l1\n");
            try normal.append("jmp l2\n");

            // TODO обработка

        } else if (eql(u8, first, "while")) {
            // TODO jmp
        } else {
            unreachable;
        }
    }

    try conctenate(&all, &data);
    try all.append("section .text\n");
    try conctenate(&all, &normal);
    try all.append("mov r15, r8\ncall _print\n");
    try all.append("exit:\nmov rax, 60\nsyscall\n");

    const output_file = try std.fs.cwd().createFile("asm/output.asm", .{});
    defer output_file.close();

    for (all.items) |value| {
        try output_file.writeAll(value);
    }
}

fn var_expr(var_name: []const u8, tokens: *std.mem.TokenIterator(u8, delim), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool)) !void {
    if (is_coplex_expr(tokens)) {
        try compute_expr(block, tokens, vars);

        try block.append("pop r8\n");
        try block.append("mov qword[");
        try block.append(var_name);
        try block.append("], r8\n");
    } else {
        const var_value = tokens.next().?;

        if (vars.contains(var_value)) {
            try block.append("push qword[");
            try block.append(var_value);
            try block.append("]\n");
        } else {
            try block.append("push ");
            try block.append(var_value);
            try block.append("\n");
        }

        try block.append("pop qword[");
        try block.append(var_name);
        try block.append("]\n");
    }
}

fn in_char(line: []const u8, char: u8) bool {
    for (line) |ch| {
        if (ch == char) {
            return true;
        }
    }
    return false;
}

fn is_coplex_expr(tokens: *std.mem.TokenIterator(u8, delim)) bool {
    if (eql(u8, tokens.peek().?, tokens.rest())) {
        return false;
    } else {
        return true;
    }
}

fn conctenate(out: *std.ArrayList([]const u8), in: *std.ArrayList([]const u8)) !void {
    for (in.items) |value| {
        try out.append(value);
    }
}

fn compute_expr(block: *std.ArrayList([]const u8), tokens: *std.mem.TokenIterator(u8, delim), vars: *std.StringHashMap(bool)) !void {
    var tree = Tree([]const u8).init(allocator);
    defer tree.deinit();
    errdefer tree.print_tree();

    try tree.pull_tree(tokens, vars);

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

pub fn what_jump_are_you(token: []const u8) []const u8 {
    if (eql(u8, token, ">")) {
        return "ja";
    } else if (eql(u8, token, "<")) {
        return "jl";
    } else if (eql(u8, token, "==")) {
        return "je";
    } else if (eql(u8, token, ">=")) {
        return "jge";
    } else if (eql(u8, token, "<=")) {
        return "jle";
    } else if (eql(u8, token, "!=")) {
        return "jne";
    }
    return "jmp";
}

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
