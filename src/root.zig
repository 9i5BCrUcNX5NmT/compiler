const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const CompileError = error{NepravilnoeVirajenie};

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();

        tree: std.ArrayList(Node),

        pub const Node = struct {
            const NodeType = enum { Oper, Var };

            value: T,
            node_type: NodeType,
            parent: ?(*Node),
            lvl: usize,
            right: ?(*Node),
            left: ?(*Node),

            fn init(token: T, lvl: usize) Node {
                return Node{
                    .value = token,
                    .node_type = if (token.len == 1) switch (token[0]) {
                        inline '+', '-', '*', '/', '=' => .Oper,
                        else => .Var,
                    } else .Var,
                    .parent = null,
                    .lvl = lvl,
                    .right = null,
                    .left = null,
                };
            }
        };

        pub fn init(allocator: Allocator) Self {
            return Self{ .tree = std.ArrayList(Node).init(allocator) };
        }

        pub fn pull_tree(self: *Self, comptime expr: T) !void {
            var tree = &self.tree;
            var node_lvl: usize = 0;
            var tokens = std.mem.tokenize(u8, expr, " ");

            while (tokens.next()) |value| {
                if (std.mem.startsWith(u8, value, "(")) {
                    node_lvl += 1;
                }

                var new_tokens = std.mem.tokenizeAny(u8, value, "()");
                while (new_tokens.next()) |token| {
                    const curr_node = Node.init(token, node_lvl);
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

        fn count_u8(str: T) usize {
            var count = 0;
            for (str) |c| {
                if (c == ' ' or c == '(' or c == ')') {
                    count += 1;
                }
            }
            return count;
        }

        pub fn print_tree(self: *Self) void {
            for (self.tree.items) |node| {
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
    };
}
