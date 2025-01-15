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

const Coord = struct {
    x: i32,
    y: i32,
};

const Direction = enum {
    NORTH,
    EAST,
    SOUTH,
    WEST,
};

fn rotate(direction: Direction) Direction {
    return switch (direction) {
        .NORTH => .WEST,
        .WEST => .SOUTH,
        .SOUTH => .EAST,
        .EAST => .NORTH,
    };
}

fn add(coord: Coord, direction: Direction) Coord {
    return switch (direction) {
        .NORTH => .{ .y = coord.y - 1, .x = coord.x },
        .WEST => .{ .y = coord.y, .x = coord.x + 1 },
        .SOUTH => .{ .y = coord.y + 1, .x = coord.x },
        .EAST => .{ .y = coord.y, .x = coord.x - 1 },
    };
}

const Map = struct {
    width: usize,
    height: usize,
    data: ArrayList([]u8),
    guard_pos: Coord,

    pub fn init(allocator: Allocator, input: []const u8) !Map {
        var data = ArrayList([]u8).init(allocator);
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        var height: usize = 0;
        var guard_pos: Coord = undefined;
        while (lines.next()) |line| : (height += 1) {
            if (std.mem.indexOf(u8, line, "^")) |idx| {
                guard_pos = .{ .y = @intCast(height), .x = @intCast(idx) };
            }
            try data.append(try allocator.dupe(u8, line));
        }
        return .{
            .width = data.items[0].len,
            .height = height,
            .data = data,
            .guard_pos = guard_pos,
        };
    }

    pub fn isInBounds(Self: Map, coord: Coord) bool {
        return (coord.y >= 0 and coord.y < Self.height and coord.x >= 0 and coord.x < Self.width);
    }

    pub fn getTile(Self: Map, coord: Coord) ?u8 {
        if (Self.isInBounds(coord)) {
            return Self.data.items[@intCast(coord.y)][@intCast(coord.x)];
        } else return null;
    }

    pub fn replaceTile(Self: Map, coord: Coord, char: u8) !void {
        if (Self.isInBounds(coord)) {
            Self.data.items[@intCast(coord.y)][@intCast(coord.x)] = char;
        } else {
            return error.OutOfBounds;
        }
    }

    pub fn deinit(Self: Map, allocator: Allocator) void {
        for (Self.data.items) |line| {
            allocator.free(line);
        }
        Self.data.deinit();
    }
};

const Guard = struct {
    pos: Coord,
    direction: Direction,

    pub fn clone(Self: Guard) Guard {
        return .{
            .pos = Self.pos,
            .direction = Self.direction,
        };
    }

    pub fn move(Self: *Guard) void {
        Self.pos = add(Self.pos, Self.direction);
    }

    pub fn turn(Self: *Guard, map: Map) void {
        for (0..4) |_| {
            const next = add(Self.pos, Self.direction);
            const tile = map.getTile(next);
            if (tile != null and tile.? == '#') {
                Self.direction = rotate(Self.direction);
            } else {
                return;
            }
        }
        unreachable;
    }
};

pub fn partTwo(allocator: Allocator, input: []const u8) !usize {
    const map = try Map.init(allocator, input);
    defer map.deinit(allocator);

    var guard = Guard{ .pos = map.guard_pos, .direction = .NORTH };

    var visited = std.AutoHashMapUnmanaged(Coord, Direction){};
    defer visited.deinit(allocator);

    var obstacles = std.AutoArrayHashMapUnmanaged(Coord, bool){};
    defer obstacles.deinit(allocator);

    while (true) {
        if (map.isInBounds(guard.pos)) {
            try visited.put(allocator, guard.pos, guard.direction);
        } else {
            break;
        }

        guard.turn(map);
        defer guard.move();

        const front = add(guard.pos, guard.direction);
        if (visited.count() < 2 or obstacles.get(front) != null) {
            continue;
        }

        var ghost = guard.clone();
        var ghost_visited = try visited.clone(allocator);
        defer ghost_visited.deinit(allocator);

        map.replaceTile(front, '#') catch continue;

        const looping = while (true) {
            ghost.turn(map);
            ghost.move();

            if (ghost_visited.get(ghost.pos)) |entry| {
                if (entry == ghost.direction)
                    break true;
            }

            if (map.isInBounds(ghost.pos)) {
                try ghost_visited.put(allocator, ghost.pos, ghost.direction);
            } else {
                break false;
            }
        };

        try obstacles.put(allocator, front, looping);

        try map.replaceTile(front, '.');
    }

    // var it = visited.iterator();
    // while (it.next()) |entry| print("[{},{}]\n", .{ entry.key_ptr.y, entry.key_ptr.x });

    var total: usize = 0;
    for (obstacles.values()) |value| {
        total += if (value) 1 else 0;
    }
    return total;
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
