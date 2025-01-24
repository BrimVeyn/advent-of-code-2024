const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const Vec2 = @Vector(2, i32);

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Turn = enum {
    LEFT,
    RIGHT,
};

const Direction = enum {
    NORTH,
    WEST,
    SOUTH,
    EAST,

    pub fn turn(self: Direction, dir: Turn) Direction {
        return switch (self) {
            .NORTH => if (dir == Turn.LEFT) .WEST else .EAST,
            .WEST => if (dir == Turn.LEFT) .SOUTH else .NORTH,
            .SOUTH => if (dir == Turn.LEFT) .EAST else .WEST,
            .EAST => if (dir == Turn.LEFT) .NORTH else .SOUTH,
        };
    }
};

const Context = struct {
    maze: ArrayList([]u8),
    deer: Vec2,
    end: Vec2,
    direction: Direction = .EAST,
    moves: usize = 0,
    turns: usize = 0,
    visited: AutoHashMap(Vec2, bool),

    pub fn clone(self: Context) !Context {
        return .{
            .maze = self.maze,
            .deer = self.deer,
            .end = self.end,
            .moves = self.moves,
            .turns = self.turns,
            .direction = self.direction,
            .visited = try self.visited.clone(),
        };
    }
};

fn parseInput(alloc: Allocator, input: []u8) !Context {
    var lines = mem.tokenizeScalar(u8, input, '\n');
    var startPos: Vec2 = undefined;
    var endPos: Vec2 = undefined;
    var y: i32 = 0;

    var maze = ArrayList([]u8).init(alloc);
    while (lines.next()) |line| : (y += 1) {
        if (mem.indexOf(u8, line, "E")) |x| {
            endPos = .{ @intCast(x), y };
        }
        if (mem.indexOf(u8, line, "S")) |x| {
            startPos = .{ @intCast(x), y };
        }
        try maze.append(try alloc.dupe(u8, line));
    }
    return .{
        .maze = maze,
        .deer = startPos,
        .end = endPos,
        .visited = AutoHashMap(Vec2, bool).init(alloc),
    };
}

fn getAdjacentsacents(maze: ArrayList([]u8), deer: Vec2, dir: Direction) struct { u8, u8 } {
    var left: Vec2 = undefined;
    var right: Vec2 = undefined;

    switch (dir) {
        .NORTH => {
            left = .{ deer[0] - 1, deer[1] };
            right = .{ deer[0] + 1, deer[1] };
        },
        .WEST => {
            left = .{ deer[0], deer[1] + 1 };
            right = .{ deer[0], deer[1] - 1 };
        },
        .SOUTH => {
            left = .{ deer[0] + 1, deer[1] };
            right = .{ deer[0] - 1, deer[1] };
        },
        .EAST => {
            left = .{ deer[0], deer[1] - 1 };
            right = .{ deer[0], deer[1] + 1 };
        },
    }

    return .{
        maze.items[@intCast(left[1])][@intCast(left[0])],
        maze.items[@intCast(right[1])][@intCast(right[0])],
    };
}

fn move(deer: *Vec2, dir: Direction) void {
    switch (dir) {
        .NORTH => deer[1] -= 1,
        .EAST => deer[0] += 1,
        .SOUTH => deer[1] += 1,
        .WEST => deer[0] -= 1,
    }
}

fn dfs(ctx: *Context, lowest_score: *?usize) !void {
    while (true) {
        // print("{any} facing {s} |M:{d}, T:{d}|\n", .{ ctx.deer, @tagName(ctx.direction), ctx.moves, ctx.turns });

        if (ctx.visited.get(ctx.deer) != null) {
            // print("Deer is loopin !\n", .{});
            return;
        }
        try ctx.visited.put(ctx.deer, true);

        const ch = ctx.maze.items[@intCast(ctx.deer[1])][@intCast(ctx.deer[0])];

        if (ch == '#') {
            // print("Hit a wall at {any}\n", .{ctx.deer});
            return;
        } else if (ch == 'E') {
            // print("Reached the end ! Cost: {d} |{d} steps, {d} turns|\n", .{ ctx.turns * 1000 + ctx.moves, ctx.moves, ctx.turns });
            const score = ctx.turns * 1000 + ctx.moves;
            if (lowest_score.*) |*lowest| {
                lowest.* = if (score < lowest.*) score else lowest.*;
            } else lowest_score.* = score;
            print("Current Lowest: {d}\n", .{lowest_score.*.?});
        }

        const left, const right = getAdjacentsacents(ctx.maze, ctx.deer, ctx.direction);
        if (left == '.' or left == 'E') {
            var new_ctx = try ctx.clone();
            new_ctx.direction = new_ctx.direction.turn(Turn.LEFT);
            new_ctx.turns += 1;

            move(&new_ctx.deer, new_ctx.direction);
            new_ctx.moves += 1;

            try dfs(&new_ctx, lowest_score);
            new_ctx.visited.deinit();
        }
        if (right == '.' or right == 'E') {
            var new_ctx = try ctx.clone();
            new_ctx.direction = new_ctx.direction.turn(Turn.RIGHT);
            new_ctx.turns += 1;

            move(&new_ctx.deer, new_ctx.direction);
            new_ctx.moves += 1;

            try dfs(&new_ctx, lowest_score);
            new_ctx.visited.deinit();
        }
        move(&ctx.deer, ctx.direction);
        ctx.moves += 1;
    }
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    var ctx = try parseInput(alloc, input);
    defer {
        for (ctx.maze.items) |line| alloc.free(line);
        ctx.visited.deinit();
        ctx.maze.deinit();
    }

    var lowest_score: ?usize = null;
    try dfs(&ctx, &lowest_score);
    return lowest_score.?;
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

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p1_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
