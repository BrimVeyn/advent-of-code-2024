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

const rl = @import("raylib");

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Context = struct {
    sequences: [5][]u8 = undefined,
    alloc: Allocator,

    pub fn init(alloc: Allocator, input: []u8) !Context {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var i: usize = 0;
        var sequences: [5][]u8 = undefined;
        while (it.next()) |line| : (i += 1) {
            sequences[i] = try alloc.dupe(u8, line);
        }

        return .{
            .sequences = sequences,
            .alloc = alloc,
        };
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginArray();
        for (self.sequences) |seq| {
            try jws.print("|{s}|", .{seq});
        }
        try jws.endArray();
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try std.json.stringify(self, .{ .whitespace = .indent_2 }, writer);
    }

    pub fn deinit(self: *Context) void {
        for (self.sequences) |code| self.alloc.free(code);
    }
};

const NumKeyPad = [_][]const u8{
    ".....",
    ".789.",
    ".456.",
    ".123.",
    "..0A.",
    ".....",
};

const DirKeyPad = [_][]const u8{
    ".....",
    "..^A.",
    ".<v>.",
    ".....",
};

const Pads = enum {
    Directionnnal,
    Numerical,
};

const Dirs = [_]struct { iVec2, u8 }{ .{ .{ 1, 0 }, '>' }, .{ .{ -1, 0 }, '<' }, .{ .{ 0, 1 }, 'v' }, .{ .{ 0, -1 }, '^' } };

const State = struct {
    pos: iVec2,
    path: ArrayList(u8),
    visited: AutoHashMap(iVec2, bool),
};

fn bfsShortest(alloc: Allocator, target: u8, start: iVec2, wPad: Pads) !ArrayList([]u8) {
    var queue = ArrayList(State).init(alloc);
    defer queue.deinit();

    var paths = ArrayList([]u8).init(alloc);

    var baseVisited = AutoHashMap(iVec2, bool).init(alloc);
    try baseVisited.put(start, true);

    const basePath = ArrayList(u8).init(alloc);
    try queue.append(State{ .path = basePath, .pos = start, .visited = baseVisited });

    var shortest: ?usize = null;

    while (queue.items.len > 0) {
        const state = queue.orderedRemove(0);
        const pos = state.pos;
        var path = state.path;
        var visited = state.visited;

        //Found target
        if ((wPad == .Numerical and NumKeyPad[@intCast(pos[1])][@intCast(pos[0])] == target) or
            (wPad == .Directionnnal and DirKeyPad[@intCast(pos[1])][@intCast(pos[0])] == target))
        {
            visited.deinit();

            if (shortest == null) {
                shortest = path.items.len;
            } else if (path.items.len > shortest.?) {
                path.deinit();
                continue;
            }
            try path.append('A'); //We need to press that key
            try paths.append(try path.toOwnedSlice());
            continue;
        }

        for (Dirs) |dir| {
            const next: iVec2 = .{ pos[0] + dir[0][0], pos[1] + dir[0][1] };

            //Out of bounds or visited
            if ((wPad == .Numerical and NumKeyPad[@intCast(next[1])][@intCast(next[0])] == '.') or
                (wPad == .Directionnnal and DirKeyPad[@intCast(next[1])][@intCast(next[0])] == '.') or
                visited.get(next) != null)
            {
                continue;
            }
            try visited.put(next, true);

            const vClone = try visited.clone();
            var clone = try path.clone();
            try clone.append(dir[1]); //Append '<>^v'
            try queue.append(State{ .pos = next, .path = clone, .visited = vClone });
        }
        path.deinit();
        visited.deinit();
    }

    return paths;
}

fn getPos(c: u8, pad: Pads) iVec2 {
    if (pad == .Numerical) {
        for (NumKeyPad, 0..) |line, y| {
            for (line, 0..) |ch, x| {
                if (ch == c) return .{ @intCast(x), @intCast(y) };
            }
        }
    } else {
        for (DirKeyPad, 0..) |line, y| {
            for (line, 0..) |ch, x| {
                if (ch == c) return .{ @intCast(x), @intCast(y) };
            }
        }
    }
    unreachable;
}

fn solveSequence(alloc: Allocator, sequence: []u8, pad: Pads) !ArrayList([]u8) {
    var ways = ArrayList([]u8).init(alloc);

    for (0..sequence.len) |i| {
        const s = if (i == 0) 'A' else sequence[i - 1];
        const e = if (i == 0) sequence[0] else sequence[i];
        const sPos = getPos(s, pad);

        const paths = try bfsShortest(alloc, e, sPos, pad);
        defer {
            for (paths.items) |path| alloc.free(path);
            paths.deinit();
        }
        var combos = ArrayList([]u8).init(alloc);

        if (i == 0) {
            for (paths.items) |path| {
                try ways.append(try alloc.dupe(u8, path));
            }
        } else {
            for (paths.items) |path| {
                for (ways.items) |way| {
                    const combined = try alloc.alloc(u8, path.len + way.len);
                    @memcpy(combined[0..way.len], way);
                    @memcpy(combined[way.len..], path);
                    try combos.append(combined);
                }
            }
            for (ways.items) |way| alloc.free(way);
            ways.deinit();
            ways = combos;
        }
    }
    return ways;
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    var ctx = try Context.init(alloc, input);
    defer ctx.deinit();

    var total: usize = 0;
    for (ctx.sequences) |sequence| {
        print("-------------TRYING: {s}------------\n", .{sequence});
        var bestWay: usize = 99999999999999;
        const numWays = try solveSequence(alloc, sequence, .Numerical);
        defer {
            for (numWays.items) |way| alloc.free(way);
            numWays.deinit();
        }
        for (numWays.items) |numWay| {
            print("Num: {s}\n", .{numWay});
            const firstRobotWay = try solveSequence(alloc, numWay, .Directionnnal);
            defer {
                for (firstRobotWay.items) |dir| alloc.free(dir);
                firstRobotWay.deinit();
            }
            for (firstRobotWay.items) |firstWay| {
                // print("First: {d}\n", .{firstWay.len});
                const secondRobotWays = try solveSequence(alloc, firstWay, .Directionnnal);
                defer {
                    for (secondRobotWays.items) |dir| alloc.free(dir);
                    secondRobotWays.deinit();
                }
                for (secondRobotWays.items) |final| {
                    // print("Second: {d}\n", .{final.len});
                    if (final.len < bestWay) {
                        bestWay = final.len;
                    }
                }
                // break;
            }
            print("Local best: {d}\n", .{bestWay});
        }
        print("Best: {d}\n", .{bestWay});
        total += (bestWay * try std.fmt.parseInt(usize, sequence[0..3], 10));
        // break;
    }

    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day21/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day21/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{res_ex});

    // const res_real = try partOne(gpa, p1_input);
    // print("Part one example result: {d}\n", .{res_real});

    // const res_ex2 = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{res_ex2});
    //
    // const res_real2 = try partTwo(gpa, p1_input);
    // print("Part two example result: {d}\n", .{res_real2});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
