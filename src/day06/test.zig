const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(allocator: Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Direction = enum {
    NORTH,
    EAST,
    SOUTH,
    WEST,
};

const Coord = struct {
    i: i32,
    j: i32,
};

const Guard = struct {
    height: usize,
    width: usize,
    direction: Direction,
    coord: Coord,

    pub fn check_bounds(Self: *Guard, coord: Coord) bool {
        return (coord.i < Self.height and coord.j < Self.width and coord.i >= 0 and coord.j >= 0);
    }

    pub fn clone(Self: *Guard) Guard {
        return .{
            .height = Self.height,
            .width = Self.width,
            .direction = Self.direction,
            .coord = Self.coord,
        };
    }

    pub fn move(Self: *Guard) Coord {
        return switch (Self.direction) {
            .NORTH => .{ .i = Self.coord.i - 1, .j = Self.coord.j },
            .EAST => .{ .i = Self.coord.i, .j = Self.coord.j + 1 },
            .SOUTH => .{ .i = Self.coord.i + 1, .j = Self.coord.j },
            .WEST => .{ .i = Self.coord.i, .j = Self.coord.j - 1 },
        };
    }

    pub fn rotate(Self: *Guard) Direction {
        return switch (Self.direction) {
            .NORTH => .EAST,
            .EAST => .SOUTH,
            .SOUTH => .WEST,
            .WEST => .NORTH,
        };
    }

    pub fn turn(Self: *Guard, map: ArrayList([]u8)) void {
        for (0..4) |_| {
            const front = Self.move();
            if (!Self.check_bounds(front))
                return;
            const tile = getChar(map, front);
            if (tile == '#') {
                Self.direction = Self.rotate();
            } else {
                return;
            }
        }
        unreachable;
    }
};

fn putChar(map: ArrayList([]u8), coord: Coord, ch: u8) void {
    map.items[@intCast(coord.i)][@intCast(coord.j)] = ch;
}

fn getChar(map: ArrayList([]u8), coord: Coord) u8 {
    return map.items[@intCast(coord.i)][@intCast(coord.j)];
}

fn dfs(data: ArrayList([]u8), guard: *Guard) void {
    // var ch: u8 = 'X';
    while (true) {
        const next_char = guard.next_char(data);
        if (next_char == 0) {
            return;
        } else if (next_char == '.') {
            data.items[@as(usize, @intCast(guard.i))][@as(usize, @intCast(guard.j))] = 'X';
            guard.total += 1;
        } else if (next_char == '#') {
            guard.prev_pos();
            data.items[@as(usize, @intCast(guard.i))][@as(usize, @intCast(guard.j))] = '+';
            guard.rotate_90();
        }
    }
}

fn getStartPos(input: ArrayList([]u8)) struct { usize, usize } {
    for (input.items, 0..) |line, i| {
        if (std.mem.indexOf(u8, line, "^")) |pos| {
            return .{ i, pos };
        }
    }
    return .{ 0, 0 };
}

fn getLoops(allocator: Allocator, map: ArrayList([]u8), guard: *Guard) !usize {
    var locations = std.AutoHashMapUnmanaged(Coord, Direction){};
    defer locations.deinit(allocator);

    var barrel = std.AutoArrayHashMapUnmanaged(Coord, bool){};
    defer barrel.deinit(allocator);

    while (true) {
        if (guard.check_bounds(guard.coord)) {
            try locations.put(allocator, guard.coord, guard.direction);
        } else {
            break;
        }

        guard.turn(map);
        defer guard.coord = guard.move();

        const front = guard.move();
        if (locations.count() < 2 or !guard.check_bounds(front) or barrel.get(front) != null)
            continue;

        putChar(map, front, '#');

        var ghost = guard.clone();
        var ghost_locations = try locations.clone(allocator);
        defer ghost_locations.deinit(allocator);

        const looping = while (true) {
            ghost.turn(map);
            ghost.coord = ghost.move();

            if (ghost_locations.get(ghost.coord)) |entry| {
                if (entry == ghost.direction) {
                    break true;
                }
            }

            if (ghost.check_bounds(ghost.coord)) {
                try ghost_locations.put(allocator, ghost.coord, ghost.direction);
            } else break false;
        };

        try barrel.put(allocator, guard.coord, looping);

        putChar(map, front, '.');
    }

    // var it = locations.iterator();
    // while (it.next()) |entry| print("K: [{},{}] V: {s}\n", .{ entry.key_ptr.i, entry.key_ptr.j, @tagName(entry.value_ptr.*) });
    // var barrel_it = barrel.iterator();
    // while (barrel_it.next()) |entry| if (entry.value_ptr.*) print("B: [{},{}]\n", .{ entry.key_ptr.i, entry.key_ptr.j });

    var total: usize = 0;
    for (barrel.values()) |value| {
        if (value)
            total += 1;
    }

    return total;
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    var data = ArrayList([]u8).init(allocator);
    defer {
        for (data.items) |line| allocator.free(line);
        data.deinit();
    }

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var height: usize = 0;
    while (lines.next()) |line| : (height += 1) {
        const mut_line = try allocator.dupe(u8, line);
        try data.append(mut_line);
    }

    const pos = getStartPos(data);
    data.items[pos[0]][pos[1]] = '.';
    var guard = Guard{
        .coord = Coord{ .i = @intCast(pos[0]), .j = @intCast(pos[1]) },
        .direction = .NORTH,
        .height = height,
        .width = data.items[0].len,
    };
    const nbLoops = try getLoops(allocator, data, &guard);
    return nbLoops;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day06/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day06/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    // const result_part_one_example = try partOne(gpa, p1_example_input);
    // print("Part one example result: {d}\n", .{result_part_one_example});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day06/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
