// возможности языка: переменные, операции, циклы, ветвления

const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;

const flags = struct { brackets: u32 };
const CompileError = error{ SyntaxError, ShadowingVariable, NepravilnoeVirajenie };
const MyError = error{NedopisanCod};

pub fn main() !void {
    // const path_to_code = "code"; // путь к файлу с кодом
    // const code = @embedFile(path_to_code);
    // const allocator = std.heap.page_allocator;

    // const lines = try trim_str(code, "\n");

    // for (lines) |value| {
    //     print("{s}\n", .{value});
    // }

    const a = "a + (b * c)";

    const tree = try gen_tree(a);

    for (tree) |node| {
        print("нода {u} типа {any} инициализирована\n\n", .{ node.value, node.node_type });
    }
}

const NodeType = enum { Oper, Var };

const Node = struct {
    value: u8,
    node_type: NodeType,
    parent: ?(*Node) = null,
    lvl: usize = 0,
    right: ?(*Node) = null,
    left: ?(*Node) = null,
};

pub fn gen_tree(comptime expr: []const u8) ![]Node {
    var node_lvl: usize = 0;

    var tree: [expr.len - count_u8(expr)]Node = undefined;
    var i: usize = 0;

    tree[0] = Node{
        .node_type = .Oper,
        .value = 0,
    };

    for (expr) |token| {
        if (token == '(') {
            node_lvl += 1;
        } else if (token == ')') {
            node_lvl -= 1;
        } else if (token != ' ') {
            const ntype: NodeType = switch (token) {
                inline '+', '-', '*', '/' => NodeType.Oper,
                else => NodeType.Var,
            };
            const new_node = Node{ .value = token, .node_type = ntype, .lvl = node_lvl };

            if (tree[0].node_type == .Oper) {
                tree[0] = new_node;
                continue;
            }
            i += 1;

            tree[i] = new_node;

            if (tree[i].node_type == tree[i - 1].node_type) {
                return CompileError.NepravilnoeVirajenie; // Гарантия чередования типов нод
            }

            if (tree[i].lvl >= tree[i - 1].lvl) {
                if (tree[i - 1].node_type == NodeType.Oper) {
                    // оператор -> val
                    tree[i - 1].left = tree[i - 1].right; // смещение налево
                    // Связь ребёнок - родитель
                    tree[i - 1].right = &tree[i];
                    tree[i].parent = &tree[i - 1];
                } else {
                    // val -> оператор
                    tree[i].right = &tree[i - 1];
                    tree[i].parent = tree[i - 1].parent;
                    tree[i - 1].right = &tree[i];
                }
            } else {
                var j = i - 1;
                while (tree[i].lvl < tree[j].lvl) {
                    j -= 1;
                }

                tree[j].right.?.parent = &tree[i];
                tree[i].right = tree[j].right;

                tree[j].right = &tree[i];
                tree[i].parent = &tree[j];
                // Должна быть гарантия чередования типов нод
            }
        }
    }

    return &tree;
}

pub fn count_u8(str: []const u8) usize {
    var count = 0;
    for (str) |c| {
        if (c == ' ' or c == '(' or c == ')') {
            count += 1;
        }
    }
    return count;
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

pub fn trim_str(str: anytype, delim: []const u8) ![][]const u8 {
    const allocator = std.heap.page_allocator;
    var lines = std.ArrayList([]const u8).init(allocator);
    var readIter = std.mem.tokenize(u8, str, delim);
    while (readIter.next()) |line| {
        try lines.append(line);
    }
    return lines.items;
}
