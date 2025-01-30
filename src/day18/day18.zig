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

const Node = struct {
    pos: uVec2,
    up: struct { ?*Node, usize } = .{ null, 0 },
    right: struct { ?*Node, usize } = .{ null, 0 },
    down: struct { ?*Node, usize } = .{ null, 0 },
    left: struct { ?*Node, usize } = .{ null, 0 },
};

const INF: usize = 9999999999;
const NodeMap = AutoArrayHashMap(uVec2, Node);

const Context = struct {
    mapSize: usize,
    memory: ArrayList(uVec2),
    memPointer: usize = 0,
    maze: [][]u8,
    nodes: NodeMap,
    adjMatrix: [][]usize,

    pub fn init(alloc: Allocator, input: []u8, mapSize: usize, readSize: usize) !Context {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var memory = ArrayList(uVec2).init(alloc);

        //Parse memory
        while (it.next()) |line| {
            const virPos = std.mem.indexOf(u8, line, ",").?;
            const x = try std.fmt.parseInt(u64, line[0..virPos], 10);
            const y = try std.fmt.parseInt(u64, line[virPos + 1 ..], 10);
            try memory.append(.{ x, y });
        }

        //Build maze
        var map = try ArrayList([]u8).initCapacity(alloc, mapSize);
        for (0..mapSize) |_| {
            var line = try ArrayList(u8).initCapacity(alloc, mapSize);
            line.appendNTimesAssumeCapacity('.', mapSize);
            map.appendAssumeCapacity(try line.toOwnedSlice());
        }
        const maze = try map.toOwnedSlice();

        //Fille corrupted
        for (0..readSize) |i| {
            const x = memory.items[i][0];
            const y = memory.items[i][1];
            maze[y][x] = '#';
        }

        var nodes = NodeMap.init(alloc);
        for (maze, 0..) |line, y| {
            for (line, 0..) |ch, x| {
                if (ch == '.') try nodes.put(.{ x, y }, .{ .pos = .{ x, y } });
            }
        }
        const nodesCount = nodes.count();

        var matrix = try ArrayList([]usize).initCapacity(alloc, nodesCount);
        for (0..nodesCount) |_| {
            var line = try ArrayList(usize).initCapacity(alloc, nodesCount);
            line.appendNTimesAssumeCapacity(INF, nodesCount);
            matrix.appendAssumeCapacity(try line.toOwnedSlice());
        }
        const adjMatrix = try matrix.toOwnedSlice();

        const keys = nodes.keys();
        for (keys, 0..) |key, i| {
            if (nodes.getIndex(.{ key[0] + 1, key[1] })) |index| {
                adjMatrix[i][index] = 1;
            }
            if (key[0] != 0) {
                if (nodes.getIndex(.{ key[0] - 1, key[1] })) |index| {
                    adjMatrix[i][index] = 1;
                }
            }
            if (nodes.getIndex(.{ key[0], key[1] + 1 })) |index| {
                adjMatrix[i][index] = 1;
            }
            if (key[1] != 0) {
                if (nodes.getIndex(.{ key[0], key[1] - 1 })) |index| {
                    adjMatrix[i][index] = 1;
                }
            }
        }

        return .{
            .memory = memory,
            .memPointer = readSize - 1,
            .mapSize = mapSize,
            .maze = maze,
            .adjMatrix = adjMatrix,
            .nodes = nodes,
        };
    }

    pub fn consumeMem(self: *Context) void {
        const x = self.memory.items[self.memPointer][0];
        const y = self.memory.items[self.memPointer][1];
        self.maze[y][x] = '#';
    }

    pub fn curuptNext(self: *Context) void {
        self.memPointer += 1;
        const ptr = self.memPointer;

        const key = self.memory.items[ptr];
        const i = self.nodes.getIndex(key).?;
        if (self.nodes.getIndex(.{ key[0] + 1, key[1] })) |index| {
            self.adjMatrix[index][i] = INF;
        }
        if (key[0] != 0) {
            if (self.nodes.getIndex(.{ key[0] - 1, key[1] })) |index| {
                self.adjMatrix[index][i] = INF;
            }
        }
        if (self.nodes.getIndex(.{ key[0], key[1] + 1 })) |index| {
            self.adjMatrix[index][i] = INF;
        }
        if (key[1] != 0) {
            if (self.nodes.getIndex(.{ key[0], key[1] - 1 })) |index| {
                self.adjMatrix[index][i] = INF;
            }
        }
    }
};

fn lessThan(context: void, a: State, b: State) std.math.Order {
    _ = context;
    return std.math.order(a.cost, b.cost);
}

const State = struct {
    idx: usize,
    cost: usize,
};

fn djikstra(alloc: Allocator, ctx: *Context, start: usize, end: usize) !usize {
    const nodesCount = ctx.nodes.count();
    var distances = try ArrayList(usize).initCapacity(alloc, nodesCount);
    var visited = try ArrayList(bool).initCapacity(alloc, nodesCount);
    var predecessors = try ArrayList(?usize).initCapacity(alloc, nodesCount);
    var queue = std.PriorityQueue(State, void, lessThan).init(alloc, {});
    defer {
        visited.deinit();
        queue.deinit();
        predecessors.deinit();
        distances.deinit();
    }

    predecessors.appendNTimesAssumeCapacity(null, nodesCount);
    distances.appendNTimesAssumeCapacity(INF, nodesCount);
    visited.appendNTimesAssumeCapacity(false, nodesCount);
    distances.items[start] = 0;
    try queue.add(.{ .idx = start, .cost = 0 });

    //0 == north, 1 = east, 2 = south, 3 = east
    var current: State = undefined;
    while (queue.count() > 0) {
        current = queue.remove();

        if (visited.items[current.idx] == true) continue;
        visited.items[current.idx] = true;

        if (current.idx == end)
            return current.cost;

        for (ctx.adjMatrix[current.idx], 0..) |dist, neighbor| {
            if (dist == INF or visited.items[neighbor])
                continue;
            const tryDist = distances.items[current.idx] + dist;
            if (tryDist < distances.items[neighbor]) {
                predecessors.items[neighbor] = current.idx;
                distances.items[neighbor] = tryDist;
                try queue.add(.{ .idx = neighbor, .cost = tryDist });
            }
        }
    }
    return 0;
}

fn partOne(alloc: Allocator, input: []u8, mapSize: usize, readSize: usize) !usize {
    var ctx = try Context.init(alloc, input, mapSize, readSize);
    defer {
        ctx.memory.deinit();
        for (ctx.maze) |line| alloc.free(line);
        alloc.free(ctx.maze);
        for (ctx.adjMatrix) |line| alloc.free(line);
        alloc.free(ctx.adjMatrix);
        ctx.nodes.deinit();
    }

    const idxStart = ctx.nodes.getIndex(.{ 0, 0 }).?;
    const idxEnd = ctx.nodes.getIndex(.{ mapSize - 1, mapSize - 1 }).?;
    const minDist = try djikstra(alloc, &ctx, idxStart, idxEnd);
    return minDist;
}

fn partTwo(alloc: Allocator, input: []u8, mapSize: usize, readSize: usize) !usize {
    var ctx = try Context.init(alloc, input, mapSize, readSize);
    defer {
        ctx.memory.deinit();
        for (ctx.maze) |line| alloc.free(line);
        alloc.free(ctx.maze);
        for (ctx.adjMatrix) |line| alloc.free(line);
        alloc.free(ctx.adjMatrix);
        ctx.nodes.deinit();
    }

    // print("{any}\n", .{ctx.memory.items});
    // for (ctx.maze) |line| print("{s}\n", .{line});
    // const keys = ctx.nodes.keys();
    // for (keys, 0..) |item, i| print("[{d}]: {any}\n", .{ i, item });

    // print("{any}\n", .{ctx.adjMatrix[34]});

    const idxStart = ctx.nodes.getIndex(.{ 0, 0 }).?;
    const idxEnd = ctx.nodes.getIndex(.{ mapSize - 1, mapSize - 1 }).?;
    while (true) {
        const minDist = try djikstra(alloc, &ctx, idxStart, idxEnd);
        if (minDist == 0) {
            print("Failed at {d}, coords: {any}\n", .{ ctx.memPointer, ctx.memory.items[ctx.memPointer] });
            return minDist;
        } else {
            print("Pointer: {d}, Found: {d}\n", .{ ctx.memPointer, minDist });
        }
        ctx.curuptNext();
    }
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day18/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day18/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input, 7, 12);
    print("Part one example result: {d}\n", .{res_ex});

    const res_real = try partOne(gpa, p1_input, 71, 1024);
    print("Part one example result: {d}\n", .{res_real});

    _ = try partTwo(gpa, p1_example_input, 7, 12);
    _ = try partTwo(gpa, p1_input, 71, 1024);

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
