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
    const allocator = std.heap.page_allocator;

    // const lines = try trim_str(code, "\n");

    // for (lines) |value| {
    //     print("{s}\n", .{value});
    // }

    const expr = "var1 = -1 + var3 * (a - t)";

    var tree = std.ArrayList(Node).init(allocator);

    try pull_tree(expr, &tree);

    for (tree.items) |node| {
        if (node.parent) |p| {
            print("parent = '{s}'\n", .{p.value});
        }
        print("node = '{s}'\n", .{node.value});
        if (node.right) |r| {
            print("children = '{s}'", .{r.value});
        }
        if (node.left) |l| {
            print(", '{s}'\n", .{l.value});
        }
        print("\n--------------------------\n", .{});
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

pub fn pull_tree(comptime expr: []const u8, tree: *std.ArrayList(Node)) !void {
    var node_lvl: usize = 0;

    var tokens = std.mem.tokenize(u8, expr, " ");

    while (tokens.next()) |value| {
        if (std.mem.startsWith(u8, value, "(")) {
            node_lvl += 1;
        }

        var new_tokens = std.mem.tokenizeAny(u8, value, "()");
        while (new_tokens.next()) |token| {
            var ntype: NodeType = undefined;
            if (token.len == 1) {
                ntype = switch (token[0]) {
                    inline '+', '-', '*', '/', '=' => .Oper,
                    else => .Var,
                };
            } else {
                ntype = .Var;
            }

            const curr_node = Node{ .value = token, .node_type = ntype, .lvl = node_lvl };
            if (tree.items.len == 0) {
                try tree.append(curr_node);
                continue;
            }

            const len = tree.items.len;
            try tree.append(curr_node); // помещаем ноду в дерево
            var prev_node = &tree.items[len - 1]; // ссылка на последнюю ноду
            const new_node = &tree.items[len]; // ссылка на новую ноду

            if (new_node.node_type == prev_node.node_type) {
                print("{s}, {any}\n", .{ token, prev_node.node_type });
                return CompileError.NepravilnoeVirajenie; // Гарантия чередования типов нод
            }

            while (prev_node.lvl > new_node.lvl) {
                if (prev_node.parent) |parent| {
                    prev_node = parent;
                } else {
                    break;
                }
            }

            if (prev_node.node_type == .Oper) {
                // Oper(prev_node) =-= Var(new_node)

                if (prev_node.lvl > new_node.lvl) {
                    new_node.right = prev_node; // закрепляем прошлую ноду к правой ветви
                    prev_node.parent = new_node; // прикрупляем новую ноду к старой
                } else {
                    prev_node.left = prev_node.right; // смещаем правую сторону
                    new_node.parent = prev_node; // закрепляем родителя новой ноды
                    prev_node.right = new_node; // прикрупляем новую ноду к правой ветви
                }
            } else {
                // Var(prev_node) =-= Oper(new_node)

                if (prev_node.parent) |parent| {
                    parent.right = new_node; // прикрепляем новую ноду
                    new_node.parent = parent; // вместо предыдущей
                }

                // предыдущую к новой
                prev_node.parent = new_node;
                new_node.right = prev_node;
            }

            if (std.mem.endsWith(u8, value, ")")) {
                node_lvl -= 1;
            }
        }
    }
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
