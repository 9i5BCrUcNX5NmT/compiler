const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const startsWith = std.mem.startsWith;
const endsWith = std.mem.endsWith;

const CompileError = error{NepravilnoeVirajenie};

pub const Node = struct {
    const NodeType = enum { Oper, Var, Const };

    value: []const u8,
    node_type: NodeType,
    parent: ?(*Node),
    lvl: usize,
    right: ?(*Node),
    left: ?(*Node),

    fn find_type(token: []const u8, vars: *std.StringHashMap(bool)) NodeType {
        if (token.len == 1) switch (token[0]) {
            inline '+', '-', '*', '/', '>', '<', '%', '|', '&' => return .Oper,
            else => {},
        } else if (eql(u8, ">=", token) or eql(u8, "<=", token) or eql(u8, "==", token) or eql(u8, "!=", token)) { // TODO булевые операции
            return .Oper;
        }
        if (vars.contains(token)) {
            return .Var;
        } else {
            return .Const;
        }
    }

    fn init(token: []const u8, lvl: usize, vars: *std.StringHashMap(bool)) Node {
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

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();

        tree: std.ArrayList(Node),
        root: ?(*Node),
        allocator: Allocator,
        output: std.ArrayList([]const u8),

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

                        if (prev_node.node_type != .Oper) {
                            prev_node = prev_node.parent.?;
                        }

                        if (prev_node.lvl > new_node.lvl or (prev_node.lvl == new_node.lvl and !(!(eql(u8, prev_node.value, "*") or eql(u8, prev_node.value, "/") or eql(u8, prev_node.value, "%") or eql(u8, prev_node.value, "&")) and (eql(u8, new_node.value, "*") or eql(u8, new_node.value, "/") or eql(u8, new_node.value, "%") or eql(u8, new_node.value, "&"))))) {
                            // 1 - 2
                            if (prev_node.parent) |parent| {
                                prev_node.parent = new_node;
                                parent.right = new_node;
                                new_node.parent = parent;
                                new_node.right = prev_node;
                            } else {
                                self.root = new_node;
                                new_node.right = prev_node;
                                prev_node.parent = new_node;
                            }
                        } else {
                            // 2 - 1
                            prev_node.right.?.parent = new_node;
                            new_node.right = prev_node.right;
                            prev_node.right = new_node;
                            new_node.parent = prev_node;
                        }
                    }
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
