const p1_real = @embedFile("p1_input.txt");
const p1_ex = @embedFile("p1_example.txt");

const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;

pub fn openAndRead(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

pub fn partOne(allocator: std.mem.Allocator, input: []const u8) !i32 {
    var lhs = std.ArrayList(i32).init(allocator);
    var rhs = std.ArrayList(i32).init(allocator);

    defer lhs.deinit();
    defer rhs.deinit();

    var splitted = std.mem.tokenizeScalar(u8, input, '\n');
    while (splitted.next()) |it| {
        var tokens = std.mem.tokenizeScalar(u8, it, ' ');
        const lhs_num = try std.fmt.parseInt(i32, tokens.next().?, 10);
        const rhs_num = try std.fmt.parseInt(i32, tokens.next().?, 10);
        try lhs.append(lhs_num);
        try rhs.append(rhs_num);
    }
    std.sort.heap(i32, lhs.items, {}, std.sort.asc(i32));
    std.sort.heap(i32, rhs.items, {}, std.sort.asc(i32));

    var delta_sum: i32 = 0;
    for (0..lhs.items.len) |i| {
        const lhs_item = lhs.items[i];
        const rhs_item = rhs.items[i];
        delta_sum += @intCast(@abs(lhs_item - rhs_item));
    }
    return delta_sum;
}

pub fn main() !void {
    const input = try openAndRead(page_allocator, "./src/day01/p1_input.txt");
    defer page_allocator.free(input); // Free the allocated memory after use

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const result_part_one = try partOne(gpa, input);
    print("Part one result: {d}\n", .{result_part_one});
}
