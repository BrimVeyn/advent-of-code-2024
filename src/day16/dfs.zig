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

fn move(deer: *Vec2, dir: Direction) void {
    switch (dir) {
        .NORTH => deer[1] -= 1,
        .EAST => deer[0] += 1,
        .SOUTH => deer[1] += 1,
        .WEST => deer[0] -= 1,
    }
}

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

pub fn dfs(ctx: *Context, lowest_score: *?usize) !void {
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
            // print("Current Lowest: {d}\n", .{lowest_score.*.?});
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
