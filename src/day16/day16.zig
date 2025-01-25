const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const uVec2 = @Vector(2, usize);
const iVec2 = @Vector(2, i32);

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Context = struct {
    maze: ArrayList([]u8),
};

const Special = enum {
    START,
    FINISH,
};

const INF: usize = 9999;

const Dir = enum(usize) {
    UP,
    RIGHT,
    DOWN,
    LEFT,
};

const Node = struct {
    pos: uVec2,
    up: ?*Node = null,
    right: ?*Node = null,
    down: ?*Node = null,
    left: ?*Node = null,
};

fn parseInput(alloc: Allocator, input: []u8) !struct { [][]u8, uVec2, uVec2 } {
    var maze = ArrayList([]u8).init(alloc);

    var lines = mem.tokenizeScalar(u8, input, '\n');
    var start: uVec2 = undefined;
    var end: uVec2 = undefined;
    var y: usize = 0;
    while (lines.next()) |line| : (y += 1) {
        if (mem.indexOf(u8, line, "S")) |x| start = .{ x, y };
        if (mem.indexOf(u8, line, "E")) |x| end = .{ x, y };
        try maze.append(try alloc.dupe(u8, line));
    }
    for (maze.items) |line| {
        print("{s}\n", .{line});
    }
    maze.items[end[1]][end[0]] = '.';
    maze.items[start[1]][start[0]] = '.';

    return .{
        try maze.toOwnedSlice(),
        start,
        end,
    };
}

fn isNode(maze: [][]u8, pos: uVec2) bool {
    const x, const y = pos;
    const paths: [4]bool = .{
        maze[y - 1][x] == '.',
        maze[y][x + 1] == '.',
        maze[y + 1][x] == '.',
        maze[y][x - 1] == '.',
    };
    const pathCount =
        @as(usize, @intFromBool(paths[0])) +
        @as(usize, @intFromBool(paths[1])) +
        @as(usize, @intFromBool(paths[2])) +
        @as(usize, @intFromBool(paths[3]));

    if ((paths[0] and !paths[2]) or (!paths[0] and paths[2]))
        return true;
    if ((paths[0] or paths[2]) and (paths[1] or paths[3]))
        return true;
    if (pathCount == 1)
        return true;
    return false;
}

fn printMapWithNodes(nodesMap: AutoArrayHashMap(uVec2, Node), maze: [][]u8) void {
    const keys = nodesMap.keys();

    for (0..keys.len) |i| {
        maze[keys[i][1]][keys[i][0]] = 'N';
    }
    for (maze) |line| std.debug.print("{s}\n", .{line});
}

const directions: [4]iVec2 = .{
    .{ 0, -1 }, //North
    .{ 1, 0 },
    .{ 0, 1 },
    .{ -1, 0 },
};

fn addOffset(vec: uVec2, offset: iVec2) uVec2 {
    return .{
        @as(u32, @intCast(@as(i32, @intCast(vec[0])) + offset[0])),
        @as(u32, @intCast(@as(i32, @intCast(vec[1])) + offset[1])),
    };
}

fn linkNode(entry: Entry, rhs: *Node, d: iVec2) void {
    switch (d[1]) {
        1 => {
            entry.value_ptr.down = rhs;
            return;
        },
        -1 => {
            entry.value_ptr.up = rhs;
            return;
        },
        else => {},
    }
    switch (d[0]) {
        1 => {
            entry.value_ptr.right = rhs;
            return;
        },
        -1 => {
            entry.value_ptr.left = rhs;
            return;
        },
        else => {},
    }
}

const Entry = AutoArrayHashMap(uVec2, Node).Entry;

fn dfs(nodesMap: AutoArrayHashMap(uVec2, Node), entry: Entry, maze: [][]u8) void {
    for (directions) |d| {
        var start = entry.key_ptr.*;
        while (true) {
            start = addOffset(start, d);
            if (maze[start[1]][start[0]] == '#')
                break;
            if (nodesMap.getPtr(start)) |rhs| {
                linkNode(entry, rhs, d);
                break;
            }
        }
    }
}

fn linkNodes(nodesMap: AutoArrayHashMap(uVec2, Node), maze: [][]u8) void {
    var it = nodesMap.iterator();

    while (it.next()) |entry| {
        dfs(nodesMap, entry, maze);
    }

    it.reset();
    while (it.next()) |entry| {
        var first: bool = true;
        print("Node: ({d},{d}) connects to: [", .{ entry.key_ptr.*[0], entry.key_ptr.*[1] });
        if (entry.value_ptr.up) |node| {
            print("U:({},{})", .{ node.pos[0], node.pos[1] });
            first = false;
        }
        if (entry.value_ptr.right) |node| {
            if (!first) print(" ", .{});
            print("R:({},{})", .{ node.pos[0], node.pos[1] });
            first = false;
        }
        if (entry.value_ptr.down) |node| {
            if (!first) print(" ", .{});
            print("D:({},{})", .{ node.pos[0], node.pos[1] });
            first = false;
        }
        if (entry.value_ptr.left) |node| {
            if (!first) print(" ", .{});
            print("L:({},{})", .{ node.pos[0], node.pos[1] });
            first = false;
        }
        print("]\n", .{});
    }
}

fn createNodes(alloc: Allocator, maze: [][]u8, start: uVec2, end: uVec2) !void {
    _ = end;
    var nodesMap = AutoArrayHashMap(uVec2, Node).init(alloc);
    defer nodesMap.deinit();

    for (maze, 0..) |line, y| {
        for (line, 0..) |ch, x| {
            if (ch == '.' and isNode(maze, .{ x, y })) {
                // print("Node at: {d},{d}\n", .{ x, y });
                try nodesMap.put(.{ x, y }, .{ .pos = .{ x, y } });
            }
        }
    }
    printMapWithNodes(nodesMap, maze);
    linkNodes(nodesMap, maze);
    _ = start;
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    const maze, const start, const end = try parseInput(alloc, input);
    defer {
        for (maze) |line| alloc.free(line);
        alloc.free(maze);
    }
    // for (maze) |line| print("{s}\n", .{line});
    try createNodes(alloc, maze, start, end);
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day16/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day16/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p1_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
