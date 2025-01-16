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
    y: i32,
    x: i32,

    pub fn equals(self: Coord, other: Coord) bool {
        return (self.x == other.x and self.y == other.y);
    }
};

const Map = struct {
    height: usize,
    width: usize,
    data: ArrayList([]u8),

    pub fn init(allocator: Allocator, input: []u8) !Map {
        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        var map = ArrayList([]u8).init(allocator);
        var height: usize = 0;
        while (lines.next()) |line| : (height += 1) {
            try map.append(try allocator.dupe(u8, line));
        }
        return .{
            .height = height,
            .width = map.items[0].len,
            .data = map,
        };
    }

    pub fn isInBounds(Self: Map, coord: Coord) bool {
        return (coord.y >= 0 and coord.y < Self.height and coord.x >= 0 and coord.x < Self.width);
    }

    pub fn deinit(Self: Map, allocator: Allocator) void {
        for (Self.data.items) |line| {
            allocator.free(line);
        }
        Self.data.deinit();
    }
};

const AntenaMap = struct {
    const Self = @This();

    raw_data: AutoHashMap(u8, ArrayList(Coord)),
    pairs: ArrayList([2]Coord),

    fn getRawData(allocator: Allocator, map: Map) !AutoHashMap(u8, ArrayList(Coord)) {
        var data = AutoHashMap(u8, ArrayList(Coord)).init(allocator);
        for (map.data.items, 0..) |line, y| {
            for (line, 0..) |ch, x| {
                if (ch == '.')
                    continue;
                const coord: Coord = .{ .y = @intCast(y), .x = @intCast(x) };
                const entry = try data.getOrPutValue(ch, ArrayList(Coord).init(allocator));
                try entry.value_ptr.append(coord);
            }
        }
        return data;
    }

    fn makePairs(allocator: Allocator, raw_data: AutoHashMap(u8, ArrayList(Coord))) !ArrayList([2]Coord) {
        var pairs = ArrayList([2]Coord).init(allocator);
        var it = raw_data.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |lhs| {
                for (entry.value_ptr.items) |rhs| {
                    if (!lhs.equals(rhs)) {
                        try pairs.append([2]Coord{ lhs, rhs });
                    }
                }
            }
        }
        return pairs;
    }

    pub fn init(allocator: Allocator, map: Map) !AntenaMap {
        const raw_data = try Self.getRawData(allocator, map);
        const pairs = try makePairs(allocator, raw_data);
        return .{
            .raw_data = raw_data,
            .pairs = pairs,
        };
    }

    pub fn deinit(self: *AntenaMap) void {
        var it = self.raw_data.iterator();
        while (it.next()) |value| {
            value.value_ptr.deinit();
        }
        self.raw_data.deinit();
        self.pairs.deinit();
    }
};

fn partOne(allocator: Allocator, input: []u8) !usize {
    var map = try Map.init(allocator, input);
    defer map.deinit(allocator);

    var antenas = try AntenaMap.init(allocator, map);
    defer antenas.deinit();

    // var it = antenas.raw_data.iterator();
    // while (it.next()) |entry| {
    //     print("[{c}]: {any}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
    // }

    var antinodes = AutoHashMap(Coord, bool).init(allocator);
    defer antinodes.deinit();

    for (antenas.pairs.items) |pair| {
        const dx = pair[1].x - pair[0].x;
        const dy = pair[1].y - pair[0].y;
        // print("[{},{}] <-> [{},{}]\n", .{ pair[0].y, pair[0].x, pair[1].y, pair[1].x });
        const antinode_coord: Coord = .{ .y = pair[0].y - dy, .x = pair[0].x - dx };
        if (map.isInBounds(antinode_coord)) {
            // print("dx: {}, dy: {} | [{},{}]\n", .{ dx, dy, antinode_coord.y, antinode_coord.x });
            try antinodes.put(antinode_coord, true);
        }
    }

    return antinodes.count();
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    var map = try Map.init(allocator, input);
    defer map.deinit(allocator);

    var antenas = try AntenaMap.init(allocator, map);
    defer antenas.deinit();

    var antinodes = AutoHashMap(Coord, bool).init(allocator);
    defer antinodes.deinit();

    for (antenas.pairs.items) |pair| {
        const dx = pair[1].x - pair[0].x;
        const dy = pair[1].y - pair[0].y;
        // print("[{},{}] <-> [{},{}]\n", .{ pair[0].y, pair[0].x, pair[1].y, pair[1].x });
        var antinode_coord: Coord = .{ .y = pair[0].y - dy, .x = pair[0].x - dx };
        while (map.isInBounds(antinode_coord)) {
            defer {
                antinode_coord.y -= dy;
                antinode_coord.x -= dx;
            }
            // print("dx: {}, dy: {} | [{},{}]\n", .{ dx, dy, antinode_coord.y, antinode_coord.x });
            try antinodes.put(antinode_coord, true);
        }
    }

    var it = antenas.raw_data.iterator();
    var antena_count: usize = 0;
    while (it.next()) |entry| {
        for (entry.value_ptr.items) |antena| {
            if (antinodes.get(antena) == null)
                antena_count += 1;
        }
    }

    return antinodes.count() + antena_count;
}
pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day08/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day08/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day08/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
