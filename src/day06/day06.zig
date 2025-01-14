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

const Direction = [4][2]i32{
    [_]i32{ -1, 0 },
    [_]i32{ 0, 1 },
    [_]i32{ 1, 0 },
    [_]i32{ 0, -1 },
};

const Ctx = struct {
    i: i32,
    j: i32,
    height: usize,
    width: usize,
    total: usize,
    current_dir: usize,

    pub fn check_bounds(Self: *Ctx) bool {
        return (Self.i < Self.height and Self.j < Self.width and Self.i >= 0 and Self.j >= 0);
    }

    pub fn next_pos(Self: *Ctx) void {
        Self.i += Direction[Self.current_dir][0];
        Self.j += Direction[Self.current_dir][1];
    }

    pub fn prev_pos(Self: *Ctx) void {
        Self.i -= Direction[Self.current_dir][0];
        Self.j -= Direction[Self.current_dir][1];
    }

    pub fn rotate_90(Self: *Ctx) void {
        Self.current_dir += 1;
        Self.current_dir %= 4;
    }

    pub fn next_char(Self: *Ctx, data: ArrayList([]u8)) u8 {
        Self.next_pos();
        if (!Self.check_bounds()) {
            return 0;
        }
        return data.items[@as(usize, @intCast(Self.i))][@as(usize, @intCast(Self.j))];
    }
};

fn dfs(data: ArrayList([]u8), context: *Ctx) void {
    while (true) {
        const next_char = context.next_char(data);
        if (next_char == 0) {
            return;
        } else if (next_char == '.') {
            data.items[@as(usize, @intCast(context.i))][@as(usize, @intCast(context.j))] = 'X';
            context.total += 1;
        } else if (next_char == '#') {
            context.prev_pos();
            context.rotate_90();
        }
        // print("--------{} {} {}----------\n", .{ context.i, context.j, context.current_dir });
        // for (data.items) |line| {
        //     print("{s}\n", .{line});
        // }
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

fn partOne(allocator: Allocator, input: []u8) !usize {
    var data = ArrayList([]u8).init(allocator);
    defer data.deinit();

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var height: usize = 0;
    while (lines.next()) |line| : (height += 1) {
        const mut_line = try allocator.dupe(u8, line);
        try data.append(mut_line);
    }

    const pos = getStartPos(data);
    data.items[pos[0]][pos[1]] = 'X';
    print("pos: {} {}\n", .{ pos[0], pos[1] });
    var context = Ctx{
        .current_dir = 0,
        .i = @as(i32, @intCast(pos[0])),
        .j = @as(i32, @intCast(pos[1])),
        .height = height,
        .width = data.items[0].len,
        .total = 0,
    };
    dfs(data, &context);
    for (data.items) |line| allocator.free(line);
    return context.total + 1; //starting pos
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day06/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day06/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    // const p2_input = try openAndRead(page_allocator, "./src/day05/p2_input.txt");
    // defer page_allocator.free(p2_input); // Free the allocated memory after use

    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});

    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
