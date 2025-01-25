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

const Direction = enum {
    UP,
    RIGHT,
    DOWN,
    LEFT,
};

const Node = struct {
    up: ?*Node = null,
    right: ?*Node = null,
    down: ?*Node = null,
    left: ?*Node = null,
};

fn parseInput(alloc: Allocator, input: []u8) !struct { [][]u8, uVec2 } {
    var maze = ArrayList([]u8).init(alloc);

    var lines = mem.tokenizeScalar(u8, input, '\n');
    var start: uVec2 = undefined;
    var y: usize = 0;
    while (lines.next()) |line| : (y += 1) {
        if (mem.indexOf(u8, line, "S")) |x| start = .{ x, y };
        try maze.append(try alloc.dupe(u8, line));
    }

    return .{
        try maze.toOwnedSlice(),
        start,
    };
}

fn isCorner(maze: [][]u8, pos: uVec2) bool {
    const x, const y = pos;
    return (maze[y - 1][x] == '.' and maze[y + 1][x] == '#' or
        maze[y + 1][x] == '.' and maze[y - 1][x] == '#');
}

fn printNodes(nodesMap: AutoArrayHashMap(uVec2, Node), maze: [][]u8) void {
    const keys = nodesMap.keys();

    for (0..keys.len) |i| {
        maze[keys[i][1]][keys[i][0]] = 'N';
    }
    for (maze) |line| std.debug.print("{s}\n", .{line});
}

fn createNodes(alloc: Allocator, maze: [][]u8, start: uVec2) !void {
    var nodesMap = AutoArrayHashMap(uVec2, Node).init(alloc);
    defer nodesMap.deinit();

    for (maze, 0..) |line, y| {
        for (line, 0..) |ch, x| {
            if (ch == '.' and isCorner(maze, .{ x, y })) {
                print("Node at: {d},{d}\n", .{ x, y });
                try nodesMap.put(.{ x, y }, .{});
                // tryLinkSouth()
            }
        }
    }
    printNodes(nodesMap, maze);
    _ = start;
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    const maze, const start = try parseInput(alloc, input);
    defer {
        for (maze) |line| alloc.free(line);
        alloc.free(maze);
    }
    for (maze) |line| print("{s}\n", .{line});
    try createNodes(alloc, maze, start);
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
