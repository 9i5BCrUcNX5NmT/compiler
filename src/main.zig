// возможности языка: переменные, операции, циклы, ветвления

const std = @import("std");
const print = std.debug.print;
const eql = std.mem.eql;
const Allocator = std.mem.Allocator;

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

    const a = "(a + b) * c";

    const tree = try gen_tree(a);
    // _ = tree;

    for (tree) |value| {
        print("нода {any}\n\n", .{value.value});
    }
}

const NodeType = enum { Oper, Var };

const Node = struct {
    value: []const u8,
    node_type: NodeType,
    parent: ?(*Node) = null,
    lvl: usize = 0,
    right: ?(*Node) = null,
    left: ?(*Node) = null,
};

pub fn gen_tree(comptime expr: []const u8, allocator: Allocator) ![]Node {
    var node_lvl: usize = 0;

    // var tree: [expr.len - count_u8(expr)]Node = undefined;
    var tree = std.ArrayList(Node).init(allocator);
    var i: usize = 0;

    const root = Node{
        .node_type = .Oper,
        .value = "",
    };

    try tree.append(root);

    var tokens = std.mem.tokenizeAny(u8, expr, " ");

    while (tokens.next()) |value| {
        if (std.mem.startsWith(u8, value, "(")) {
            node_lvl += 1;
        }

        var new_tokens = std.mem.tokenizeAny(u8, value, "()");
        while (new_tokens.next()) |token| {
            const ntype: NodeType = switch (token[0]) {
                inline '+', '-', '*', '/' => .Oper,
                else => .Var,
            };

            const new_node = Node{ .value = token, .node_type = ntype, .lvl = node_lvl };
            if (eql(u8, tree[0].value, "")) {
                tree[0] = new_node;
                continue;
            }
            i += 1;

            tree[i] = new_node;

            var j = i - 1; // index ноды прикрепления

            if (tree[i].node_type == tree[j].node_type) {
                return CompileError.NepravilnoeVirajenie; // Гарантия чередования типов нод
            }

            if (tree[i].lvl >= tree[j].lvl) {
                if (tree[j].node_type == NodeType.Oper) {
                    // оператор -> val
                    tree[j].left = tree[j].right; // смещение налево
                    // Связь ребёнок - родитель
                    tree[j].right = &tree[i];
                    tree[i].parent = &tree[j];
                } else {
                    // val -> оператор
                    tree[i].right = &tree[j];
                    if (tree[j].parent) |_| {
                        tree[i].parent = tree[j].parent;
                    }
                    tree[j].parent = &tree[i];
                }
            } else {
                while (tree[i].lvl < tree[j].lvl and j > 0) {
                    j -= 1;
                }
                if (j == 0) {
                    if (tree[j].node_type == .Var) {
                        j += 1;
                    }
                    tree[j].parent = &tree[i];
                    tree[i].right = &tree[j];
                } else {
                    tree[j].right.?.parent = &tree[i];
                    tree[i].right = tree[j].right;

                    tree[j].right = &tree[i];
                    tree[i].parent = &tree[j];
                }
                // Должна быть гарантия чередования типов нод
            }
            if (std.mem.endsWith(u8, value, ")")) {
                node_lvl -= 1;
            }
        }
    }

    // for (tree) |value| {
    //     print("нода {any}\n\n", .{value.parent});
    // }

    // for (tree) |node| {
    //     print("noda {s} \n", .{node.value});
    //     if (node.parent) |p| {
    //         print("имеет родителя {s} \n", .{p.value});
    //     }
    //     if (node.right) |r| {
    //         print("левого ребёнка {s} || ", .{r.value});
    //     }
    //     if (node.left) |l| {
    //         print("и правого ребёнка {s}\n", .{l.value});
    //     }
    //     print("\n--------------------------\n", .{});
    // }

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
