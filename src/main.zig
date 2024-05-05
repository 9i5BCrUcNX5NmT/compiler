const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;

const Tree = @import("root.zig").Tree;

const CompileError = error{ SyntaxError, ShadowingVariable, NedopisanCod };
const allocator = std.heap.page_allocator;
const var_type = "dq";
const delim: std.mem.DelimiterType = .any;

var label_counter: u8 = 1;

var start: usize = 0;
var buf: [1024]u8 = undefined; // максимум лейблов = 45
var fbs = std.io.fixedBufferStream(&buf);
const writer = fbs.writer();

const flag = enum { Loop, NotLoop };
var expr_flag: flag = .NotLoop;

pub fn main() !void {
    const path_to_code = "code"; // путь к файлу с кодом
    const code = @embedFile(path_to_code);

    var lines = std.mem.tokenize(u8, code, "\n");

    var vars = std.StringHashMap(bool).init(allocator);
    defer vars.deinit();
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

    try bracket_expr(&lines, &normal, &data, &vars);

    try conctenate(&all, &data);
    try all.append("section .text\n");
    try conctenate(&all, &normal);
    try all.append("exit:\nmov rax, 60\nsyscall\n");

    const output_file = try std.fs.cwd().createFile("asm/output.asm", .{});
    defer output_file.close();

    for (all.items) |value| {
        try output_file.writeAll(value);
    }
}

fn bracket_expr(lines: *std.mem.TokenIterator(u8, delim), normal: *std.ArrayList([]const u8), data: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool)) !void {
    while (lines.next()) |line| {
        var tokens = std.mem.tokenize(u8, line, " ");
        const first = tokens.next().?;
        var var_name: []const u8 = undefined;

        if (eql(u8, first, "{")) {
            try normal.append("start");
            try normal.append(try current_label());
            try normal.append(":\n");
            try bracket_expr(lines, normal, data, vars);
        } else if (eql(u8, first, "}")) {
            if (expr_flag == .Loop) {
                try normal.append("jmp ");
                try normal.append("loop");
                try normal.append(try current_label());
                try normal.append("\n");

                expr_flag = .NotLoop;
            }

            try normal.append("end");
            try normal.append(try current_label());
            try normal.append(":\n");
            label_counter += 1;
            break;
        } else if (!eql(u8, first, "if") and !eql(u8, first, "while") and !eql(u8, first, "print")) {
            var_name = first;
            _ = tokens.next().?; // = TODO может быть ошибка если нет равно в выражении

            if (!vars.contains(var_name)) {
                try vars.put(var_name, true); // добавлени в спиисок переменных

                try data.append(var_name);
                try data.append(" ");
                try data.append(var_type);
                try data.append(" 0\n");
            }

            try var_expr(var_name, &tokens, normal, vars);
        } else if (eql(u8, first, "if")) {
            try if_expr(&tokens, normal, vars);
        } else if (eql(u8, first, "while")) {
            expr_flag = .Loop;

            try while_expr(&tokens, normal, vars);
        } else if (eql(u8, first, "print")) {
            try print_expr(&tokens, normal, vars);
        } else {
            unreachable;
        }
    }
}

fn current_label() ![]const u8 {
    try writer.print("{d}", .{label_counter});

    if (label_counter > 45) {
        return CompileError.NedopisanCod;
    }

    const written = fbs.getWritten();
    const label = written[start..];
    start = written.len;

    return label;
}

fn print_expr(tokens: *std.mem.TokenIterator(u8, delim), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool)) !void {
    if (is_coplex_expr(tokens)) {
        try compute_expr(block, tokens, vars);
    } else {
        try block.append("push ");

        const nxt = tokens.next().?;
        if (vars.contains(nxt)) {
            try block.append("qword[");
            try block.append(nxt);
            try block.append("]");
        } else {
            try block.append(nxt);
        }
        try block.append("\n");
    }

    try block.append("pop r15\ncall _print\n"); // зависимость от библиотеки print_digit.asm
}

fn if_expr(tokens: *std.mem.TokenIterator(u8, delim), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool)) !void {
    try compute_expr(block, tokens, vars);

    try block.append("pop r8\ncmp r8, 0\njne start");
    try block.append(try current_label());
    try block.append("\njmp ");
    try block.append("end");
    try block.append(try current_label());
    try block.append("\n");
}

fn while_expr(tokens: *std.mem.TokenIterator(u8, delim), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool)) !void {
    try block.append("loop");
    try block.append(try current_label());
    try block.append(":\n");

    try compute_expr(block, tokens, vars); // TODO cmp

    try block.append("pop r8\ncmp r8, 0\njne start");
    try block.append(try current_label());
    try block.append("\njmp ");
    try block.append("end");
    try block.append(try current_label());
    try block.append("\n");
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

    try tree.gen_output(try current_label());

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
