const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Point = struct {
    y: i32,
    x: i32,
};

const Sides = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
};

const Context = struct {
    visited: *AutoArrayHashMap(Point, bool),
    sides: usize,
    id: u8,
    p: Point,
    area: usize,
    perimeter: usize,
};

const directions: [4]Point = .{ .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = -1, .y = 0 }, .{ .x = 0, .y = -1 } };
const corners: [4]Point = .{ .{ .x = 1, .y = 1 }, .{ .x = -1, .y = 1 }, .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 } };

fn inBounds(map: ArrayList([]u8), p: Point) bool {
    return (p.y >= 0 and p.y < map.items.len and p.x >= 0 and p.x < map.items[0].len);
}

fn isFence(map: ArrayList([]u8), p: Point, id: u8) bool {
    return (map.items[@intCast(p.y)][@intCast(p.x)] != id or
        map.items[@intCast(p.y)][@intCast(p.x)] == '.');
}

fn dfs(ctx: *Context, map: ArrayList([]u8)) !void {
    if (!inBounds(map, ctx.p) or ctx.visited.get(ctx.p) != null)
        return;
    if (map.items[@intCast(ctx.p.y)][@intCast(ctx.p.x)] != ctx.id)
        return;

    ctx.area += 1;
    try ctx.visited.put(ctx.p, true);

    const base_point = ctx.p;

    var neighbours: [4]bool = .{ false, false, false, false };

    for (0..directions.len) |i| {
        ctx.p.x += directions[i].x;
        ctx.p.y += directions[i].y;

        if (!inBounds(map, ctx.p) or isFence(map, ctx.p, ctx.id)) {
            ctx.perimeter += 1;
        } else {
            neighbours[i] = true;
            try dfs(ctx, map);
        }

        ctx.p = base_point;
    }

    for (corners, 0..) |corner, j| {
        if (!neighbours[j] and !neighbours[(j + 1) % 4]) {
            ctx.sides += 1;
        }
        const cor = Point{ .x = ctx.p.x + corner.x, .y = ctx.p.y + corner.y };
        if (inBounds(map, cor)) {
            if (map.items[@intCast(cor.y)][@intCast(cor.x)] == ctx.id)
                continue;
        }
        if (neighbours[j] and neighbours[(j + 1) % 4]) {
            ctx.sides += 1;
        }
    }
}

fn partOne(allocator: Allocator, input: []u8) !usize {
    var map = ArrayList([]u8).init(allocator);
    defer {
        for (map.items) |item| allocator.free(item);
        map.deinit();
    }

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try map.append(try allocator.dupe(u8, line));
    }

    // print("{s}\n", .{map.items});
    var visited = AutoArrayHashMap(Point, bool).init(allocator);
    defer visited.deinit();

    var total_cost: usize = 0;

    for (map.items, 0..) |line, i| {
        for (line, 0..) |ch, j| {
            if (ch < 'A' or ch > 'Z' or visited.get(.{ .y = @intCast(i), .x = @intCast(j) }) != null)
                continue;
            var ctx: Context = .{
                .visited = &visited,
                .p = .{ .x = @intCast(j), .y = @intCast(i) },
                .id = ch,
                .area = 0,
                .perimeter = 0,
                .sides = 0,
            };

            try dfs(&ctx, map);
            // print("id: {c}, area: {d}, sides: {d}\n", .{ ctx.id, ctx.area, ctx.sides.count() });
            total_cost += (ctx.area * ctx.perimeter);
        }
    }
    return total_cost;
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    var map = ArrayList([]u8).init(allocator);
    defer {
        for (map.items) |item| allocator.free(item);
        map.deinit();
    }

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try map.append(try allocator.dupe(u8, line));
    }

    // print("{s}\n", .{map.items});
    var visited = AutoArrayHashMap(Point, bool).init(allocator);
    defer visited.deinit();

    var total_cost: usize = 0;

    for (map.items, 0..) |line, i| {
        for (line, 0..) |ch, j| {
            if (ch < 'A' or ch > 'Z' or visited.get(.{ .y = @intCast(i), .x = @intCast(j) }) != null)
                continue;
            var ctx: Context = .{
                .visited = &visited,
                .p = .{ .x = @intCast(j), .y = @intCast(i) },
                .id = ch,
                .area = 0,
                .perimeter = 0,
                .sides = 0,
            };

            try dfs(&ctx, map);
            print("id: {c}, area: {d}, sides: {d}\n", .{ ctx.id, ctx.area, ctx.sides });
            total_cost += (ctx.area * ctx.sides);
        }
    }
    return total_cost;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day12/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day12/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead("./src/day12/p1_input.txt", page_allocator);
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
