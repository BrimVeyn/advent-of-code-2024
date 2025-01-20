const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(allocator: Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

fn parseMap(allocator: Allocator, input: []u8) !ArrayList([]u8) {
    var array = ArrayList([]u8).init(allocator);
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        try array.append(try allocator.dupe(u8, line));
    }
    return array;
}

const Point = struct {
    x: i32 = 5,
    y: i32 = 5,

    pub const default: Point = .{
        .x = 0,
        .y = 0,
    };
};

const Context = struct {
    p: Point,
    trails: AutoArrayHashMap(Point, bool),
    rating: *usize,

    pub const default: Context = .{
        .p = .default,
        .trails = undefined,
        .rating = undefined,
    };

    pub fn init(allocator: Allocator, y: usize, x: usize) !Context {
        return .{
            .p = .{
                .y = @intCast(y),
                .x = @intCast(x),
            },
            .rating = try allocator.create(usize),
            .trails = AutoArrayHashMap(Point, bool).init(allocator),
        };
    }
};

fn inBounds(map: ArrayList([]u8), p: Point) bool {
    return (p.y >= 0 and p.y < map.items.len and p.x >= 0 and p.x < map.items[0].len);
}

fn dfs(ctx: *Context, map: ArrayList([]u8)) !void {
    if (!inBounds(map, ctx.p))
        return;

    const current = map.items[@intCast(ctx.p.y)][@intCast(ctx.p.x)];
    if (current == '9') {
        try ctx.trails.put(ctx.p, true);
        ctx.rating.* += 1;
        return;
    }

    const save = ctx.p;

    //go up
    ctx.p.y -= 1;
    if (inBounds(map, ctx.p) and map.items[@intCast(ctx.p.y)][@intCast(ctx.p.x)] == current + 1) {
        try dfs(ctx, map);
    }
    //go down
    ctx.p = save;
    ctx.p.y += 1;
    if (inBounds(map, ctx.p) and map.items[@intCast(ctx.p.y)][@intCast(ctx.p.x)] == current + 1) {
        try dfs(ctx, map);
    }
    //go left
    ctx.p = save;
    ctx.p.x -= 1;
    if (inBounds(map, ctx.p) and map.items[@intCast(ctx.p.y)][@intCast(ctx.p.x)] == current + 1) {
        try dfs(ctx, map);
    }

    ctx.p = save;
    ctx.p.x += 1;
    if (inBounds(map, ctx.p) and map.items[@intCast(ctx.p.y)][@intCast(ctx.p.x)] == current + 1) {
        try dfs(ctx, map);
    }
}

fn partOne(allocator: Allocator, input: []u8) !usize {
    const map = try parseMap(allocator, input);
    defer {
        for (map.items) |item| allocator.free(item);
        map.deinit();
    }

    var total: usize = 0;
    for (0..map.items.len) |y| {
        for (0..map.items[0].len) |x| {
            if (map.items[y][x] == '0') {
                var ctx = try Context.init(allocator, y, x);
                defer {
                    ctx.trails.deinit();
                    allocator.destroy(ctx.rating);
                }
                try dfs(&ctx, map);
                const score = ctx.trails.count();
                // print("score: {}\n", .{score});
                total += score;
            }
        }
    }
    // print("map: {s}\n", .{map.items});
    return total;
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    const map = try parseMap(allocator, input);
    defer {
        for (map.items) |item| allocator.free(item);
        map.deinit();
    }

    var total: usize = 0;
    for (0..map.items.len) |y| {
        for (0..map.items[0].len) |x| {
            if (map.items[y][x] == '0') {
                var ctx = try Context.init(allocator, y, x);
                ctx.rating.* = 0;
                defer {
                    allocator.destroy(ctx.rating);
                    ctx.trails.deinit();
                }
                try dfs(&ctx, map);
                total += ctx.rating.*;
            }
        }
    }

    // print("map: {s}\n", .{map.items});
    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day10/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day10/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day10/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
