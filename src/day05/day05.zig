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
    var splits = std.mem.splitScalar(u8, input, '\n');
    while (splits.next()) |line| {
        try array.append(line);
    }
    return array;
}

fn partOne(allocator: Allocator, input: []const u8) !usize {
    const total: usize = 0;
    const lines = try splitLine(allocator, input);
    var header: [][]const u8 = undefined;
    var footer: [][]const u8 = undefined;

    for (lines.items, 0..) |line, i| {
        // print("line: {s}\n", .{line});
        if (line.len == 0) {
            // print("Found newline\n", .{});
            header = lines.items[0..i];
            footer = lines.items[i + 1 .. lines.items.len - 1];
            break;
        }
    }

    for (header) |line| {
        print("header: {s}\n", .{line});
    }

    for (footer) |line| {
        print("footer: {s}\n", .{line});
    }

    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day05/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day04/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});

    // const p2_example_input = try openAndRead(page_allocator, "./src/day04/p1_example.txt");
    // defer page_allocator.free(p2_example_input); // Free the allocated memory after use
    //
    // const p2_input = try openAndRead(page_allocator, "./src/day04/p2_input.txt");
    // defer page_allocator.free(p2_input); // Free the allocated memory after use
    //
    // const result_part_two_example = try partTwo(gpa, p2_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});
}
