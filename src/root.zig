const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const endsWith = std.mem.endsWith;

const CompileError = error{NepravilnoeVirajenie};

// регистры для декомпозиции дерева
const reg1 = "r8";
const reg2 = "r9";
const reg1_small = "r8w";
const reg2_small = "r9w";

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();

        tree: std.ArrayList(Node),
        root: ?(*Node),
        allocator: Allocator,
        output: std.ArrayList([]const u8),

        pub const Node = struct {
            const NodeType = enum { Oper, Var };

            value: T,
            node_type: NodeType,
            parent: ?(*Node),
            lvl: usize,
            right: ?(*Node),
            left: ?(*Node),

            fn find_type(token: T) NodeType {
                if (token.len == 1) switch (token[0]) {
                    inline '+', '-', '*', '/', '=', '>', '<', '%' => return .Oper,
                    else => return .Var,
                };

                if (eql(u8, ">=", token) or eql(u8, "<=", token) or eql(u8, "or", token) or eql(u8, "and", token)) {
                    return .Oper;
                } else {
                    return .Var;
                }
            }

            fn init(token: T, lvl: usize) Node {
                return Node{
                    .value = token,
                    .node_type = find_type(token),
                    .parent = null,
                    .lvl = lvl,
                    .right = null,
                    .left = null,
                };
            }
        };

        pub fn init(allocator: Allocator) Self {
            return Self{ .tree = std.ArrayList(Node).init(allocator), .allocator = allocator, .output = std.ArrayList([]const u8).init(allocator), .root = null };
        }

        pub fn deinit(self: *Self) void {
            self.tree.deinit();
            self.output.deinit();
        }

        pub fn pull_tree(self: *Self, tokens: *std.mem.TokenIterator(u8, .any)) !void {
            var tree = &self.tree;
            var node_lvl: usize = 0;

            while (tokens.next()) |value| {
                if (startsWith(u8, value, "(")) { // контроль скобочек
                    node_lvl += 1;
                }

                var new_tokens = std.mem.tokenizeAny(u8, value, "()");
                while (new_tokens.next()) |token| {
                    const curr_node = Node.init(token, node_lvl);
                    if (tree.items.len == 0) {
                        try tree.append(curr_node);
                        continue;
                    } else if (tree.items.len == 2) {
                        self.root = &tree.items[1];
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
                            self.root = new_node;
                            new_node.right = prev_node; // закрепляем прошлую ноду к правой ветви
                            prev_node.parent = new_node; // прикрупляем новую ноду к старой
                        } else {
                            if (prev_node.left) |_| {
                                new_node.right = prev_node.right;
                                prev_node.right.?.parent = new_node;
                            } else {
                                prev_node.left = prev_node.right; // смещаем правую сторону
                            }
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

                    if (endsWith(u8, value, ")")) {
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
                if (node.left) |l| {
                    print("children = '{s}'", .{l.value});
                }
                if (node.right) |r| {
                    print(", '{s}'\n", .{r.value});
                }
                print("\n--------------------------\n", .{});
            }
        }

        pub fn gen_output(self: *Self) !void {
            const root = self.root.?;
            try push_node(self, root);
        }

        fn push_node(self: *Self, node: *Node) !void {
            var str = &self.output;
            if (node.node_type == .Var) {
                try str.append("push ");
                try str.append(node.value);
                try str.append("\n");
            } else {
                try push_node(self, node.right.?);
                try push_node(self, node.left.?);

                try str.append("pop ");
                try str.append(reg1);
                try str.append("\n");

                try str.append("pop ");
                try str.append(reg2);
                try str.append("\n");

                const operation = oper_to_asm(node.value);
                try str.append(operation);
                try str.append(" ");
                if (eql(u8, operation, "imul")) {
                    try str.append(reg1_small);
                    try str.append(", ");
                    try str.append(reg2_small);
                    try str.append("\n");

                    try str.append("push ");
                    try str.append(reg1);
                    try str.append("\n");
                } else if (eql(u8, node.value, "%")) {
                    try str.append(reg2);
                    try str.append("\n");
                    try str.append("push rdx\n");
                } else if (eql(u8, node.value, "/")) {
                    try str.append(reg2);
                    try str.append("\n");
                    try str.append("push rax\n");
                } else {
                    try str.append(reg1);
                    try str.append(", ");
                    try str.append(reg2);
                    try str.append("\n");

                    try str.append("push ");
                    try str.append(reg1);
                    try str.append("\n");
                }
            }
        }

        fn oper_to_asm(oper: T) []const u8 {
            return if (oper.len == 1) switch (oper[0]) {
                '+' => "add",
                '-' => "sub",
                '*' => "imul", // mul работает криво
                '=' => "mov",
                inline '%', '/' => "idiv",
                // '/' => "div", // TODO
                // else => "cmp",
                else => unreachable,
            } else unreachable;

            // if (eql(u8, ">=", oper) or eql(u8, "<=", oper) or eql(u8, "or", oper) or eql(u8, "and", oper)) {
            //     return .Oper;
            // } else {
            //     return .Var;
            // }

        }
    };
}
