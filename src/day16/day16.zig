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

const Entry = AutoArrayHashMap(uVec2, Node).Entry;

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const INF: usize = 9999999999;

const Cost = [4]usize;

const Node = struct {
    pos: uVec2,
    up: struct { ?*Node, Cost } = .{ null, .{ 0, 0, 0, 0 } },
    right: struct { ?*Node, Cost } = .{ null, .{ 0, 0, 0, 0 } },
    down: struct { ?*Node, Cost } = .{ null, .{ 0, 0, 0, 0 } },
    left: struct { ?*Node, Cost } = .{ null, .{ 0, 0, 0, 0 } },
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

//up, right, down, left

const TURN: usize = 1000;

fn linkNode(entry: Entry, rhs: *Node, dir: iVec2, dist: usize) void {
    switch (dir[1]) {
        1 => {
            entry.value_ptr.down[0] = rhs;
            entry.value_ptr.down[1] = .{ INF, dist + TURN, dist, dist + TURN };
            return;
        },
        -1 => {
            entry.value_ptr.up[0] = rhs;
            entry.value_ptr.up[1] = .{ dist, dist + TURN, INF, dist + TURN };
            return;
        },
        else => {},
    }
    switch (dir[0]) {
        1 => {
            entry.value_ptr.right[0] = rhs;
            entry.value_ptr.right[1] = .{ dist + TURN, dist, dist + TURN, INF };
            return;
        },
        -1 => {
            entry.value_ptr.left[0] = rhs;
            entry.value_ptr.left[1] = .{ dist + TURN, INF, dist + TURN, dist };
            return;
        },
        else => {},
    }
}

fn printNode(mb_node: struct { ?*Node, usize }, ch: u8, space: bool) bool {
    if (mb_node[0] != null) {
        if (!space) print(" ", .{});
        print("{c}:({},{})|D{d}|", .{ ch, mb_node[0].?.pos[0], mb_node[0].?.pos[1], mb_node[1] });
        return false;
    }
    return space;
}

fn printNodes(nodesMap: AutoArrayHashMap(uVec2, Node)) void {
    var it = nodesMap.iterator();
    while (it.next()) |entry| {
        print("Node: ({d},{d})\t connects to: [", .{ entry.key_ptr.*[0], entry.key_ptr.*[1] });
        var first: bool = true;
        first = printNode(entry.value_ptr.up, 'U', first);
        first = printNode(entry.value_ptr.right, 'R', first);
        first = printNode(entry.value_ptr.down, 'D', first);
        first = printNode(entry.value_ptr.left, 'L', first);
        print("]\n", .{});
    }
}

fn dfs(nodesMap: AutoArrayHashMap(uVec2, Node), entry: Entry, maze: [][]u8) void {
    for (directions) |dir| {
        var start = entry.key_ptr.*;
        var dist: usize = 0;
        while (true) {
            start = addOffset(start, dir);
            dist += 1;
            if (maze[start[1]][start[0]] == '#')
                break;
            if (nodesMap.getPtr(start)) |rhs| {
                linkNode(entry, rhs, dir, dist);
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
}

fn createNodes(alloc: Allocator, maze: [][]u8) !AutoArrayHashMap(uVec2, Node) {
    var nodesMap = AutoArrayHashMap(uVec2, Node).init(alloc);

    for (maze, 0..) |line, y| {
        for (line, 0..) |ch, x| {
            if (ch == '.' and isNode(maze, .{ x, y })) {
                try nodesMap.put(.{ x, y }, .{ .pos = .{ x, y } });
            }
        }
    }
    printMapWithNodes(nodesMap, maze);
    linkNodes(nodesMap, maze);
    return nodesMap;
}

fn fillLine(node: struct { ?*Node, Cost }, nodesMap: AutoArrayHashMap(uVec2, Node), line: *ArrayList(Cost)) void {
    if (node[0] != null) {
        const up_idx = nodesMap.getIndex(node[0].?.pos).?;
        line.items[up_idx] = node[1];
    }
}

fn buildAdjMatrix(alloc: Allocator, nodesMap: AutoArrayHashMap(uVec2, Node)) ![][]Cost {
    const nodesCount = nodesMap.count();
    var matrix = try ArrayList([]Cost).initCapacity(alloc, nodesCount);

    var it = nodesMap.iterator();
    while (it.next()) |entry| {
        var line = try ArrayList(Cost).initCapacity(alloc, nodesCount);
        line.appendNTimesAssumeCapacity(.{ INF, INF, INF, INF }, nodesCount);
        fillLine(entry.value_ptr.up, nodesMap, &line);
        fillLine(entry.value_ptr.right, nodesMap, &line);
        fillLine(entry.value_ptr.down, nodesMap, &line);
        fillLine(entry.value_ptr.left, nodesMap, &line);
        matrix.appendAssumeCapacity(try line.toOwnedSlice());
    }
    return try matrix.toOwnedSlice();
}

const Order = std.math.Order;

const State = struct {
    idx: usize,
    dir: usize,
    cost: usize,
};

fn lessThan(context: void, a: State, b: State) Order {
    _ = context;
    return std.math.order(a.cost, b.cost);
}

fn dirToStr(dir: usize) []const u8 {
    return switch (dir) {
        0 => "UP",
        1 => "RIGHT",
        2 => "DOWN",
        3 => "LEFT",
        else => "NONE",
    };
}

fn minIndex(arr: [4]usize) usize {
    var lowestNum: usize = arr[0];
    var lowestIndex: usize = 0;
    for (arr, 0..) |item, i| {
        if (item < lowestNum) {
            lowestNum = item;
            lowestIndex = i;
        }
    }
    return lowestIndex;
}

fn debugPath(maze: [][]u8, from: uVec2, to: uVec2) void {
    const dy: i32 = @as(i32, @intCast(to[1])) - @as(i32, @intCast(from[1]));
    const dx: i32 = @as(i32, @intCast(to[0])) - @as(i32, @intCast(from[0]));
    // print("from {} to {}, dy {}\n", .{ from, to, dy });

    const drawS = if (dy > 0 or dx > 0) to else from;
    for (0..@abs(dy + dx) + 1) |iy| {
        maze[drawS[1] - if (dy != 0) iy else 0][drawS[0] - if (dx != 0) iy else 0] = '+';
    }
    drawColorized(maze);
    return;
}

fn djikstra(alloc: Allocator, adjMatrix: [][]Cost, start: usize, end: usize, nodesMap: AutoArrayHashMap(uVec2, Node), maze: [][]u8) !struct { distance: usize, path: ArrayList([4]?usize), distances: ArrayList([4]usize) } {
    const nodesCount = adjMatrix.len;

    var distances = try ArrayList([4]usize).initCapacity(alloc, nodesCount);
    var visited = try ArrayList([4]bool).initCapacity(alloc, nodesCount);
    var predecessors = try ArrayList([4]?usize).initCapacity(alloc, nodesCount);
    var queue = std.PriorityQueue(State, void, lessThan).init(alloc, {});
    defer {
        visited.deinit();
        queue.deinit();
    }

    predecessors.appendNTimesAssumeCapacity(.{ null, null, null, null }, nodesCount);
    distances.appendNTimesAssumeCapacity(.{ INF, INF, INF, INF }, nodesCount);
    visited.appendNTimesAssumeCapacity(.{ false, false, false, false }, nodesCount);
    distances.items[start] = .{ 0, 0, 0, 0 };
    try queue.add(.{ .idx = start, .cost = 0, .dir = 1 });

    //0 == north, 1 = east, 2 = south, 3 = east
    var current: State = undefined;
    // var known_min: ?usize = null;
    while (queue.count() > 0) {
        current = queue.remove();

        if (visited.items[current.idx][current.dir] == true) continue;
        visited.items[current.idx][current.dir] = true;

        const pos = nodesMap.keys()[current.idx];
        print("Node[{d}]: {any}, {s}, {d}\n", .{ current.idx, pos, dirToStr(current.dir), current.cost });

        if (current.idx == end) {
            print("HEY ! reached: {d}\n", .{end});
            break;
        }

        for (adjMatrix[current.idx], 0..) |dist, neighbor| {
            if (dist[current.dir] == INF or visited.items[neighbor][current.dir]) continue;

            // print("current_dir:{s} : Dist: {any}\n", .{ dirToStr(current.dir), dist });
            const tryDist = distances.items[current.idx][current.dir] + dist[current.dir];
            _ = maze;
            // const to = nodesMap.keys()[neighbor];
            // debugPath(maze, pos, to);
            // print("trydist: {d}, distance_neighbor: {d}, Nei:{d}\n", .{ tryDist, distances.items[current.idx][current.dir], neighbor });
            const newDir = minIndex(dist);
            if (tryDist < distances.items[neighbor][newDir]) {
                predecessors.items[neighbor][newDir] = current.idx;
                distances.items[neighbor][newDir] = tryDist;
                try queue.add(.{ .idx = neighbor, .dir = newDir, .cost = tryDist });
            } else if (tryDist == distances.items[neighbor][newDir]) {
                print("SOMETHING COOL HAPPEND\n", .{});
            }
        }
        // print("{any}\n", .{queue.items});
        // break;
    }
    for (distances.items, 0..) |dist, i| {
        print("dist[{d}]: {any}\n", .{ i, dist });
    }
    return .{ .distance = current.cost, .path = predecessors, .distances = distances };
}

fn drawColorized(maze: [][]u8) void {
    const blue = "\x1b[34m"; // ANSI code for blue
    const reset = "\x1b[0m"; // ANSI code to reset colors}

    for (maze) |line| {
        for (line) |ch| {
            if (ch != '+') {
                print("{c}", .{ch});
                continue;
            } else {
                print("{s}{c}{s}", .{ blue, ch, reset });
            }
        }
        print("\n", .{});
    }
}

fn fillPath(maze: [][]u8, from: uVec2, to: uVec2) void {
    const dy: i32 = @as(i32, @intCast(to[1])) - @as(i32, @intCast(from[1]));
    const dx: i32 = @as(i32, @intCast(to[0])) - @as(i32, @intCast(from[0]));
    // print("from {} to {}, dy {}\n", .{ from, to, dy });

    const drawS = if (dy > 0 or dx > 0) to else from;
    for (0..@abs(dy + dx) + 1) |iy| {
        maze[drawS[1] - if (dy != 0) iy else 0][drawS[0] - if (dx != 0) iy else 0] = '+';
    }
    return;
}

fn countPaths(maze: [][]u8) usize {
    var count: usize = 0;
    for (maze) |line| {
        for (line) |ch| {
            if (ch == '+') count += 1;
        }
    }
    return count;
}

fn countNonNull(pre: [4]?usize) usize {
    var count: usize = 0;
    for (pre) |value| {
        if (value != null) count += 1;
    }
    return count;
}

fn drawPath(
    alloc: Allocator,
    path: ArrayList([4]?usize),
    maze: [][]u8,
    end: usize,
    start: usize,
    nodesMap: AutoArrayHashMap(uVec2, Node),
    distances: ArrayList([4]usize),
) !void {
    _ = start;
    var nodeStack = ArrayList(usize).init(alloc);
    var visited = AutoArrayHashMap(usize, bool).init(alloc);
    defer {
        nodeStack.deinit();
        visited.deinit();
    }

    try nodeStack.append(end);

    const lowest = minIndex(distances.items[end]);
    print("lowest{d}, {any}\n", .{ lowest, distances.items[end] });
    for (0..path.items[end].len) |i| {
        if (i != lowest) path.items[end][i] = null;
    }

    // var localScore: usize = 0;
    while (true) {
        const current = nodeStack.popOrNull() orelse break;
        if (visited.get(current) != null) continue;

        const sPoint = path.items[current];
        const keyTo = nodesMap.keys()[current];

        for (sPoint) |node| {
            if (node != null) {
                const keyFrom = nodesMap.keys()[node.?];
                fillPath(maze, keyFrom, keyTo);
                try nodeStack.append(node.?);
            }
        }
        try visited.put(current, true);
    }
    return;
}

fn partOne(alloc: Allocator, input: []u8) !struct { usize, usize } {
    const maze, const start, const end = try parseInput(alloc, input);
    defer {
        for (maze) |line| alloc.free(line);
        alloc.free(maze);
    }
    var nodesMap: AutoArrayHashMap(uVec2, Node) = try createNodes(alloc, maze);
    defer nodesMap.deinit();

    // printNodes(nodesMap);

    const adjMatrix = try buildAdjMatrix(alloc, nodesMap);
    defer {
        for (adjMatrix) |line| alloc.free(line);
        alloc.free(adjMatrix);
    }

    // for (adjMatrix) |line| {
    //     print("{any}\n", .{line});
    // }

    const startIdx = nodesMap.getIndex(start).?;
    const endIdx = nodesMap.getIndex(end).?;

    print("start: {}, end: {}\n", .{ start, end });
    const sToE = try djikstra(alloc, adjMatrix, startIdx, endIdx, nodesMap, maze);
    defer {
        sToE.path.deinit();
        sToE.distances.deinit();
    }

    for (sToE.path.items, 0..) |item, i| {
        print("predecessors[{d}]: {any}\n", .{ i, item });
    }
    try drawPath(alloc, sToE.path, maze, endIdx, startIdx, nodesMap, sToE.distances);
    drawColorized(maze);
    return .{
        sToE.distance,
        countPaths(maze),
    };
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day16/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day16/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const cost, const paths = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}, {d}\n", .{ cost, paths });

    // const cost_real, const paths_real = try partOne(gpa, p1_input);
    // print("Part one example result: {d}, {d}\n", .{ cost_real, paths_real });

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
