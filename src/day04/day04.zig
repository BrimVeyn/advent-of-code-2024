const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

fn openAndRead(allocator: Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

fn splitLine(allocator: Allocator, input: []const u8) !ArrayList([]const u8) {
    var array = ArrayList([]const u8).init(allocator);
    var splits = std.mem.tokenizeScalar(u8, input, '\n');
    while (splits.next()) |line| {
        try array.append(line);
    }
    return array;
}

const Ctx = struct {
    i: i32,
    j: i32,
    height: i32,
    width: i32,

    pub fn check_bounds(Self: *Ctx) bool {
        return (Self.i < Self.height and Self.j < Self.width and Self.i >= 0 and Self.j >= 0);
    }

    pub fn next_pos(Self: *Ctx, direction: [2]i32) void {
        Self.i += direction[0];
        Self.j += direction[1];
    }
};

fn dfa(direction: [2]i32, lines: ArrayList([]const u8), context: *Ctx) bool {
    const to_find = "MAS";
    for (to_find) |ch| {
        context.next_pos(direction);
        if (!context.check_bounds()) {
            return false;
        } else if (lines.items[@as(usize, @intCast(context.i))][@as(usize, @intCast(context.j))] != ch) {
            return false;
        }
    }
    return true;
}

fn partOne(allocator: Allocator, input: []const u8) !usize {
    const lines = try splitLine(allocator, input);
    const line_height = lines.items.len;
    const line_width = lines.items[0].len;

    const directions = [8][2]i32{
        [_]i32{ 0, -1 }, [_]i32{ 0, 1 }, //left, right
        [_]i32{ 1, 0 }, [_]i32{ -1, 0 }, //up, dowm
        [_]i32{ 1, 1 }, [_]i32{ -1, -1 }, //diag up-left down-right
        [_]i32{ 1, -1 }, [_]i32{ -1, 1 }, //diag up-right down-right
    };

    var total: usize = 0;
    for (0..lines.items.len) |i| {
        const line = lines.items[i];
        for (0..line.len) |j| {
            if (line[j] == 'X') {
                for (directions) |direction| {
                    var context = Ctx{
                        .width = @as(i32, @intCast(line_width)),
                        .height = @as(i32, @intCast(line_height)),
                        .i = @as(i32, @intCast(i)),
                        .j = @as(i32, @intCast(j)),
                    };
                    const found = dfa(direction, lines, &context);
                    // if (found) {
                    //     print("found at: {d} {d}, direction: {d} {d}\n", .{ i, j, direction[0], direction[1] });
                    // }
                    total += if (found) 1 else 0;
                }
            }
        }
    }
    return total;
}

fn diag_check(diag: [2][2]i32, lines: ArrayList([]const u8), context: *Ctx) bool {
    var mas = [_]bool{false} ** 256;
    context.next_pos(diag[0]);
    if (!context.check_bounds())
        return false;
    var ch = lines.items[@as(usize, @intCast(context.i))][@as(usize, @intCast(context.j))];
    mas[ch] = true;
    context.next_pos(diag[1]);
    if (!context.check_bounds())
        return false;
    ch = lines.items[@as(usize, @intCast(context.i))][@as(usize, @intCast(context.j))];
    mas[ch] = true;
    return (mas['M'] == true and mas['S'] == true);
}

fn partTwo(allocator: Allocator, input: []const u8) !usize {
    const lines = try splitLine(allocator, input);
    const line_height = lines.items.len;
    const line_width = lines.items[0].len;

    const diag_left = [2][2]i32{
        [_]i32{ -1, -1 }, [_]i32{ 2, 2 },
    };
    const diag_right = [2][2]i32{
        [_]i32{ 1, -1 }, [_]i32{ -2, 2 },
    };

    var total: usize = 0;

    for (0..lines.items.len) |i| {
        const line = lines.items[i];
        for (0..line.len) |j| {
            if (line[j] == 'A') {
                var context = Ctx{
                    .width = @as(i32, @intCast(line_width)),
                    .height = @as(i32, @intCast(line_height)),
                    .i = @as(i32, @intCast(i)),
                    .j = @as(i32, @intCast(j)),
                };
                // print("found A at: {d},{d}\n", .{ i, j });
                const diag_left_found = diag_check(diag_left, lines, &context);
                context.next_pos(diag_left[0]);
                const diag_right_found = diag_check(diag_right, lines, &context);
                if (diag_left_found and diag_right_found)
                    total += 1;
            }
        }
    }
    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day04/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day04/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_example_input = try openAndRead(page_allocator, "./src/day04/p1_example.txt");
    defer page_allocator.free(p2_example_input); // Free the allocated memory after use

    const p2_input = try openAndRead(page_allocator, "./src/day04/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p2_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});
}
