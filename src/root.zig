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
            const NodeType = enum { Oper, Var, Const };

            value: T,
            node_type: NodeType,
            parent: ?(*Node),
            lvl: usize,
            right: ?(*Node),
            left: ?(*Node),

            fn find_type(token: T, vars: *std.StringHashMap(bool)) NodeType {
                if (token.len == 1) switch (token[0]) {
                    inline '+', '-', '*', '/', '=', '>', '<', '%', '|', '&' => return .Oper,
                    else => {},
                } else if (eql(u8, ">=", token) or eql(u8, "<=", token) or eql(u8, "==", token)) { // TODO булевые операции
                    return .Oper;
                }
                if (vars.contains(token)) {
                    return .Var;
                } else {
                    return .Const;
                }
            }

            fn init(token: T, lvl: usize, vars: *std.StringHashMap(bool)) Node {
                return Node{
                    .value = token,
                    .node_type = find_type(token, vars),
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

        pub fn pull_tree(self: *Self, tokens: *std.mem.TokenIterator(u8, .any), vars: *std.StringHashMap(bool)) !void {
            var tree = &self.tree;
            var node_lvl: usize = 0;

            while (tokens.next()) |value| {
                if (startsWith(u8, value, "(")) { // контроль скобочек
                    node_lvl += 1;
                }

                var new_tokens = std.mem.tokenizeAny(u8, value, "()");

                while (new_tokens.next()) |token| {
                    const curr_node = Node.init(token, node_lvl, vars);

                    const len = tree.items.len;

                    try tree.append(curr_node); // помещаем ноду в дерево

                    if (len == 0) {
                        continue;
                    }

                    var prev_node = &tree.items[len - 1]; // ссылка на предыдущую ноду
                    const new_node = &tree.items[len]; // ссылка на новую ноду

                    if (len == 1) {
                        self.root = new_node;
                        new_node.right = prev_node;
                        prev_node.parent = new_node;
                        continue;
                    }

                    if ((new_node.node_type == .Const or new_node.node_type == .Var) and
                        (prev_node.node_type == .Const or prev_node.node_type == .Var) or
                        new_node.node_type == prev_node.node_type)
                    {
                        return CompileError.NepravilnoeVirajenie; // Гарантия чередования типов нод
                    }

                    if (prev_node.node_type == .Oper) {
                        prev_node.left = prev_node.right;
                        prev_node.right = new_node;
                        new_node.parent = prev_node;
                    } else {
                        while (prev_node.lvl > new_node.lvl) {
                            if (prev_node.parent) |parent| {
                                prev_node = parent;
                            } else {
                                break;
                            }
                        }

                        if (prev_node.lvl > new_node.lvl) {
                            self.root = new_node;
                            new_node.right = prev_node;
                            prev_node.parent = new_node;
                        } else {
                            if (prev_node.node_type != .Oper) {
                                prev_node = prev_node.parent.?;
                            }
                            if (prev_node.lvl == new_node.lvl and (eql(u8, prev_node.value, "*") or eql(u8, prev_node.value, "/") or eql(u8, prev_node.value, "&")) and !(eql(u8, new_node.value, "*") or eql(u8, new_node.value, "/") or eql(u8, new_node.value, "&"))) {
                                const parent = prev_node.parent.?;
                                prev_node.parent = new_node;
                                parent.right = new_node;
                                new_node.parent = parent;
                                new_node.right = prev_node;
                            } else {
                                prev_node.right.?.parent = new_node;
                                new_node.right = prev_node.right;
                                prev_node.right = new_node;
                                new_node.parent = prev_node;
                                // prnode - oper | var
                                // if (prev_node.parent) |parent| {
                                //     parent.right = new_node;
                                //     new_node.parent = parent;
                                // } else {
                                //     self.root = new_node;
                                // }
                                // new_node.right = prev_node;
                                // prev_node.parent = new_node;
                            }
                        }
                    }

                    // while (prev_node.lvl > new_node.lvl) {
                    //     if (prev_node.parent) |parent| {
                    //         prev_node = parent;
                    //     } else {
                    //         break;
                    //     }
                    // }

                    // if (prev_node.lvl > new_node.lvl) {
                    //     // Oper(prev_node)
                    //     //  -_
                    //     //    -_
                    //     //      Oper(new_node)

                    //     self.root = new_node;
                    //     new_node.right = prev_node; // закрепляем прошлую ноду к правой ветви
                    //     prev_node.parent = new_node; // прикрупляем новую ноду к старой
                    // } else {
                    //     if (new_node.node_type == .Oper) {
                    //         // Var(prev_node)
                    //         //  -_
                    //         //    -_
                    //         //      Oper(new_node)

                    //         if ((eql(u8, new_node.value, "+") or eql(u8, new_node.value, "-")) and (new_node.lvl == prev_node.lvl)) {
                    //             new_node.right = prev_node;
                    //             prev_node.parent = new_node;
                    //             if (self.root.?.lvl == new_node.lvl) {
                    //                 self.root = new_node;
                    //             }
                    //         } else {
                    //             if (prev_node.parent) |parent| {
                    //                 if (parent.left) |_| {
                    //                     new_node.right = prev_node;
                    //                     prev_node.parent = new_node;
                    //                 } else {
                    //                     parent.left = parent.right; // смещаем правую сторону
                    //                 }

                    //                 new_node.parent = parent; // закрепляем родителя новой ноды
                    //                 parent.right = new_node; // прикрепляем новую ноду к правой ветви
                    //             } else {
                    //                 return CompileError.NepravilnoeVirajenie;
                    //             }
                    //         }
                    //     } else {
                    //         // Oper(prev_node)
                    //         //  -_
                    //         //    -_
                    //         //      Var(new_node)
                    //         prev_node.left = prev_node.right; // смещаем правую сторону
                    //         prev_node.right = new_node;
                    //         new_node.parent = prev_node;
                    //     }

                }

                if (endsWith(u8, value, ")")) {
                    node_lvl -= 1;
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
                print("\n--------------------------\n", .{});
                if (node.parent) |p| {
                    print("parent = '{s}'\n", .{p.value});
                }
                print("node = '{s}'\n", .{node.value});
                print("nodeType = '{any}'\n", .{node.node_type});
                print("nodelvl = '{any}'\n", .{node.lvl});
                if (node.left) |l| {
                    print("left = '{s}'\n", .{l.value});
                }
                if (node.right) |r| {
                    print("right = '{s}'\n", .{r.value});
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
                try str.append("push qword[");
                try str.append(node.value);
                try str.append("]\n");
            } else if (node.node_type == .Const) {
                try str.append("push ");
                try str.append(node.value);
                try str.append("\n");
            } else {
                try push_node(self, node.right.?);
                try push_node(self, node.left.?);

                const operation = oper_to_asm(node.value);

                if (eql(u8, operation, "idiv")) {
                    try str.append("pop rax\n");
                    try str.append("cqo\n");
                } else {
                    try str.append("pop ");
                    try str.append(reg1);
                    try str.append("\n");
                }

                try str.append("pop ");
                try str.append(reg2);
                try str.append("\n");

                try str.append(operation);
                try str.append(" ");

                if (eql(u8, operation, "idiv")) {
                    try str.append(reg2);
                    try str.append("\n");

                    if (eql(u8, node.value, "%")) {
                        try str.append("push rdx\n");
                    } else if (eql(u8, node.value, "/")) {
                        try str.append("push rax\n");
                    }
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
                '|' => "or",
                '&' => "and",
                inline '%', '/' => "idiv",
                // else => "cmp", TODO
                else => unreachable,
            } else unreachable;
        }
    };
}

test "(a + b) * 5 test" {
    const expect = std.testing.expect;

    const str = "(a + b) * 5";
    const allocator = std.testing.allocator;

    var tokens = std.mem.tokenizeAny(u8, str, " ");
    var vars = std.StringHashMap(bool).init(allocator);
    defer vars.deinit();

    try vars.put("a", true);
    try vars.put("b", true);

    var tree = Tree([]const u8).init(allocator);
    defer tree.deinit();
    try tree.pull_tree(&tokens, &vars);

    try expect(eql(u8, tree.tree.items[0].value, "a") and tree.tree.items[0].node_type == .Var);
    try expect(eql(u8, tree.tree.items[1].value, "+") and tree.tree.items[1].node_type == .Oper);
    try expect(eql(u8, tree.tree.items[2].value, "b") and tree.tree.items[2].node_type == .Var);
    try expect(eql(u8, tree.tree.items[3].value, "*") and tree.tree.items[3].node_type == .Oper);
    try expect(eql(u8, tree.tree.items[4].value, "5") and tree.tree.items[4].node_type == .Const);
}

test "a * b + c test" {
    const expect = std.testing.expect;

    const str = "a * b + c";
    const allocator = std.testing.allocator;

    var tokens = std.mem.tokenizeAny(u8, str, " ");
    var vars = std.StringHashMap(bool).init(allocator);
    defer vars.deinit();

    try vars.put("a", true);
    try vars.put("b", true);
    try vars.put("c", true);

    var tree = Tree([]const u8).init(allocator);
    defer tree.deinit();
    errdefer tree.print_tree();
    try tree.pull_tree(&tokens, &vars);

    try expect(eql(u8, tree.tree.items[0].parent.?.value, "*"));
    try expect(eql(u8, tree.tree.items[2].parent.?.value, "*"));
    try expect(eql(u8, tree.tree.items[3].right.?.value, "c"));
    try expect(eql(u8, tree.tree.items[3].left.?.value, "*"));
}
