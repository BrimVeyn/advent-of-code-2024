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

const Coord = struct {
    y: i32,
    x: i32,
};

const DiagMap = struct {
    primDiag: ArrayList(ArrayList(u8)),
    antiDiag: ArrayList(ArrayList(u8)),

    const Steps = [2][2]i32{
        [_]i32{ -1, -1 },
        [_]i32{ 1, 1 },
    };

    pub fn init(allocator: Allocator, input: []u8) !DiagMap {
        var map = try Map.init(allocator, input);
        defer map.deinit(allocator);
        var primary = ArrayList(ArrayList(u8)).init(allocator);

        var floor = Coord{ .y = @intCast(map.data.items.len), .x = 0 };
        while (true) {
            if (!map.isInBounds(floor))
                break;
            defer floor.x += 1;

            var diagonal = ArrayList(u8).init(allocator);

            var it = Coord{ .x = floor.x, .y = floor.y };
            while (true) {
                defer {
                    it.y -= 1;
                    it.x -= 1;
                }
                if (!map.isInBounds(floor))
                    break;
                try diagonal.append(map.data.items[@intCast(floor.y)][@intCast(floor.x)]);
            }
            try primary.append(diagonal);
        }

        return .{
            .primDiag = primary,
            .antiDiag = primary,
        };
    }

    pub fn deinit(Self: DiagMap) void {
        for (Self.antiDiag.items) |diag| {
            diag.deinit();
        }
        Self.antiDiag.deinit();
        for (Self.primDiag.items) |diag| {
            diag.deinit();
        }
        Self.primDiag.deinit();
    }
};

fn partOne(allocator: Allocator, input: []u8) !usize {
    var diagMap = try DiagMap.init(allocator, input);
    defer diagMap.deinit();
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day08/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    // const p1_input = try openAndRead(page_allocator, "./src/day07/p1_input.txt");
    // defer page_allocator.free(p1_input); // Free the allocated memory after use
    //
    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});
    //
    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});
    //
    // const p2_input = try openAndRead(page_allocator, "./src/day07/p2_input.txt");
    // defer page_allocator.free(p2_input); // Free the allocated memory after use
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
