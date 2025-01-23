const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Direction: [4]@Vector(2, i32) = .{
    .{ 0, -1 },
    .{ 1, 0 },
    .{ 0, 1 },
    .{ -1, 0 },
};

const Part = enum(i32) {
    One,
    Two,
};

const Vec2 = @Vector(2, i32);

const Context = struct {
    map: ArrayList([]u8),
    moves: ArrayList(Vec2),
    lantern: Vec2,
};

fn parseMap(allocator: Allocator, map: []const u8, p: Part) !struct { Vec2, ArrayList([]u8) } {
    var ret = ArrayList([]u8).init(allocator);
    var lines = mem.tokenizeScalar(u8, map, '\n');
    var lantern: Vec2 = undefined;
    var y: i32 = 0;

    while (lines.next()) |line| : (y += 1) {
        const maybe_x = mem.indexOf(u8, line, "@");
        if (maybe_x) |x| {
            const real_x: i32 = if (p == Part.One) @intCast(x) else @intCast(x * 2);
            lantern = .{ real_x, y };
        }
        if (p == Part.One) {
            try ret.append(try allocator.dupe(u8, line));
            continue;
        }
        var line_arr = ArrayList(u8).init(allocator);
        for (line) |ch| {
            switch (ch) {
                '.' => try line_arr.appendSlice(".."),
                '#' => try line_arr.appendSlice("##"),
                'O' => try line_arr.appendSlice("[]"),
                '@' => try line_arr.appendSlice("@."),
                else => {},
            }
        }
        try ret.append(try line_arr.toOwnedSlice());
    }
    return .{
        lantern,
        ret,
    };
}

fn parseMoves(allocator: Allocator, moves: []const u8) !ArrayList(Vec2) {
    var ret = ArrayList(Vec2).init(allocator);
    var lines = mem.splitBackwardsScalar(u8, moves, '\n');
    while (lines.next()) |line| {
        for (0..line.len) |i| {
            switch (line[line.len - i - 1]) {
                '^' => try ret.append(Direction[0]),
                '>' => try ret.append(Direction[1]),
                'v' => try ret.append(Direction[2]),
                '<' => try ret.append(Direction[3]),
                else => {},
            }
        }
    }
    return ret;
}

fn parseInput(allocator: Allocator, input: []u8, p: Part) !Context {
    var it = std.mem.tokenizeSequence(u8, input, "\n\n");
    const lantern, const map = try parseMap(allocator, it.next().?, p);
    const moves = try parseMoves(allocator, it.next().?);
    return .{
        .map = map,
        .moves = moves,
        .lantern = lantern,
    };
}

var moveIt: i32 = 0;

fn printMap(map: ArrayList([]u8), move: @Vector(2, i32)) void {
    var ch: u8 = '0';
    switch (move[0]) {
        0 => {},
        else => {
            if (move[0] == 1) ch = '>';
            if (move[0] == -1) ch = '<';
        },
    }
    switch (move[1]) {
        0 => {},
        else => {
            if (move[1] == 1) ch = 'v';
            if (move[1] == -1) ch = '^';
        },
    }
    print("\nMove {d} {c}:\n", .{ moveIt, ch });
    for (map.items) |line| {
        print("{s}\n", .{line});
    }
}

fn computeGPS(map: ArrayList([]u8)) usize {
    var total: usize = 0;
    for (map.items, 0..) |line, y| {
        for (line, 0..) |ch, x| {
            if (ch == 'O' or ch == '[') {
                total += (100 * y + x);
            }
        }
    }
    return total;
}

fn partOne(allocator: Allocator, input: []u8) !usize {
    var ctx = try parseInput(allocator, input, Part.One);
    defer {
        for (ctx.map.items) |item| allocator.free(item);
        ctx.map.deinit();
        ctx.moves.deinit();
    }

    while (ctx.moves.popOrNull()) |move| {
        const nextX = ctx.lantern[0] + move[0];
        const nextY = ctx.lantern[1] + move[1];
        if (ctx.map.items[@intCast(nextY)][@intCast(nextX)] == '#') {
            // printMap(ctx.map, move);
            continue;
        }

        if (ctx.map.items[@intCast(nextY)][@intCast(nextX)] == '.') {
            ctx.map.items[@intCast(ctx.lantern[1])][@intCast(ctx.lantern[0])] = '.';
            ctx.map.items[@intCast(nextY)][@intCast(nextX)] = '@';
            ctx.lantern = .{ nextX, nextY };
        } else {
            var start: Vec2 = .{ nextX, nextY };
            // print("Start: {d},{d}\n", .{ nextY, nextX });
            while (ctx.map.items[@intCast(start[1])][@intCast(start[0])] == 'O') {
                start[0] += move[0];
                start[1] += move[1];
            }
            if (ctx.map.items[@intCast(start[1])][@intCast(start[0])] == '#') {
                // printMap(ctx.map, move);
                continue;
            }
            // print("Next: {d},{d}\n", .{ nextY, nextX });
            // print("Caisse: {d},{d}\n", .{ start[1], start[0] });
            ctx.map.items[@intCast(nextY)][@intCast(nextX)] = '@';
            ctx.map.items[@intCast(ctx.lantern[1])][@intCast(ctx.lantern[0])] = '.';
            ctx.map.items[@intCast(start[1])][@intCast(start[0])] = 'O';
            ctx.lantern = .{ nextX, nextY };
        }
        // printMap(ctx.map, move);
    }

    return computeGPS(ctx.map);
}

fn findBox(boxes: *ArrayList(Vec2), box: Vec2) ?bool {
    for (boxes.items) |item| {
        if (item[0] == box[0] and item[1] == box[1])
            return true;
    }
    return null;
}

fn collectVert(allocator: Allocator, ctx: Context, boxes: *ArrayList(Vec2), dY: i32) !bool {
    var visited = AutoArrayHashMap(Vec2, bool).init(allocator);
    defer visited.deinit();

    while (true) {
        if (visited.count() == boxes.items.len) break;
        var dup_boxes = try boxes.clone();
        defer {
            boxes.deinit();
            boxes.* = dup_boxes;
        }

        for (boxes.items) |box| {
            if (visited.get(box) != null)
                continue;

            const ch = ctx.map.items[@intCast(box[1] + dY)][@intCast(box[0])];
            if (ch == ']' or ch == '[') {
                const vertOne = Vec2{ box[0], box[1] + dY };
                var vertOneHor = Vec2{ box[0], box[1] + dY };
                vertOneHor[0] += if (ch == '[') 1 else -1;
                if (findBox(&dup_boxes, vertOne) == null) try dup_boxes.append(vertOne);
                if (findBox(&dup_boxes, vertOneHor) == null) try dup_boxes.append(vertOneHor);
            } else if (ch == '#') return false;
            try visited.put(box, true);
        }
    }
    return true;
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    var ctx = try parseInput(allocator, input, Part.Two);
    defer {
        for (ctx.map.items) |item| allocator.free(item);
        ctx.map.deinit();
        ctx.moves.deinit();
    }
    // printMap(ctx.map, .{ 0, 0 });
    while (ctx.moves.popOrNull()) |move| : (moveIt += 1) {
        const nextX = ctx.lantern[0] + move[0];
        const nextY = ctx.lantern[1] + move[1];
        if (ctx.map.items[@intCast(nextY)][@intCast(nextX)] == '#') {
            // printMap(ctx.map, move);
            continue;
        }

        if (ctx.map.items[@intCast(nextY)][@intCast(nextX)] == '.') {
            ctx.map.items[@intCast(ctx.lantern[1])][@intCast(ctx.lantern[0])] = '.';
            ctx.map.items[@intCast(nextY)][@intCast(nextX)] = '@';
            ctx.lantern = .{ nextX, nextY };
        } else {
            if (move[0] != 0) {
                var boxes = ArrayList(Vec2).init(allocator);
                defer boxes.deinit();

                var start: Vec2 = .{ nextX, nextY };
                // print("Start: {d},{d}\n", .{ nextY, nextX });
                while (ctx.map.items[@intCast(start[1])][@intCast(start[0])] == '[' or
                    ctx.map.items[@intCast(start[1])][@intCast(start[0])] == ']')
                {
                    try boxes.append(start);
                    start[0] += move[0];
                    start[1] += move[1];
                }
                if (ctx.map.items[@intCast(start[1])][@intCast(start[0])] == '#') {
                    continue;
                }

                // print("boxes: {any}\n", .{boxes.items});
                for (0..boxes.items.len) |i| {
                    const box_half = boxes.items[boxes.items.len - i - 1];
                    ctx.map.items[@intCast(box_half[1])][@intCast(box_half[0] + move[0])] = ctx.map.items[@intCast(box_half[1])][@intCast(box_half[0])];
                }
                ctx.map.items[@intCast(nextY)][@intCast(nextX)] = '@';
                ctx.map.items[@intCast(ctx.lantern[1])][@intCast(ctx.lantern[0])] = '.';
                ctx.lantern = .{ nextX, nextY };
            } else {
                var boxes = ArrayList(Vec2).init(allocator);
                defer boxes.deinit();

                try boxes.append(.{ nextX, nextY });
                if (ctx.map.items[@intCast(nextY)][@intCast(nextX - 1)] == '[') {
                    try boxes.append(.{ nextX - 1, nextY });
                } else {
                    try boxes.append(.{ nextX + 1, nextY });
                }
                // printMap(ctx.map, move);
                const canMove = try collectVert(allocator, ctx, &boxes, move[1]);
                if (canMove) {
                    for (0..boxes.items.len) |i| {
                        const item = boxes.items[boxes.items.len - i - 1];
                        const box_half = ctx.map.items[@intCast(item[1])][@intCast(item[0])];
                        ctx.map.items[@intCast(item[1])][@intCast(item[0])] = '.';
                        ctx.map.items[@intCast(item[1] + move[1])][@intCast(item[0])] = box_half;
                    }
                    ctx.map.items[@intCast(ctx.lantern[1])][@intCast(ctx.lantern[0])] = '.';
                    ctx.lantern = boxes.items[0];
                    ctx.map.items[@intCast(ctx.lantern[1])][@intCast(ctx.lantern[0])] = '@';
                }
            }
        }
        // printMap(ctx.map, move);
    }
    return computeGPS(ctx.map);
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day15/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day15/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p1_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
