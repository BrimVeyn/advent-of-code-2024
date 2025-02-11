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

fn dfa_mult(input: []const u8) u64 {
    var total: u64 = 0;

    var state: usize = 0;
    var num_len: usize = 0;
    var operands: [2]u64 = .{ 0, 0 };
    for (input) |ch| {
        // print("ch: {c} : {d} lhs: {d} rhs: {d}\n", .{ ch, state, operands[0], operands[1] });
        switch (state) {
            0 => {
                if (ch == 'm') {
                    state = 1;
                } else state = 0;
            },
            1 => {
                if (ch == 'u') {
                    state = 2;
                } else state = 0;
            },
            2 => {
                if (ch == 'l') {
                    state = 3;
                } else state = 0;
            },
            3 => {
                if (ch == '(') {
                    state = 4;
                } else state = 0;
            },
            4 => {
                if (num_len < 3 and ch >= '0' and ch <= '9') {
                    operands[0] = operands[0] * 10 + (ch - '0');
                    num_len += 1;
                } else if (num_len != 0 and ch == ',') {
                    state = 5;
                    num_len = 0;
                } else {
                    state = 0;
                    num_len = 0;
                    operands = .{ 0, 0 };
                }
            },
            5 => {
                if (num_len < 3 and ch >= '0' and ch <= '9') {
                    operands[1] = operands[1] * 10 + (ch - '0');
                    num_len += 1;
                } else if (num_len != 0 and ch == ')') {
                    state = 0;
                    num_len = 0;
                    total = total + (operands[0] * operands[1]);
                    // print("mul({d},{d})\n", .{ operands[0], operands[1] });
                    operands = .{ 0, 0 };
                } else {
                    state = 0;
                    num_len = 0;
                    operands = .{ 0, 0 };
                }
            },
            else => {},
        }
    }
    return total;
}

fn partOne(input: []const u8) !u64 {
    return dfa_mult(input);
}

fn partTwo(input: []const u8) !u64 {
    var match_start: usize = 0;
    var match_end: usize = 0;
    var total: u64 = 0;
    var it: usize = 0;
    while (true) {
        if (it == 0) {
            match_end = std.mem.indexOfPos(u8, input, match_start, "don't()") orelse input.len - 1;
            total += dfa_mult(input[match_start..match_end]);
        }
        match_start = std.mem.indexOfPos(u8, input, match_start, "do()") orelse break;
        match_end = std.mem.indexOfPos(u8, input, match_start, "don't()") orelse input.len - 1;

        // print("slice: {s}\n", .{input[match_start..match_end]});
        // print("it: {d]\n", .{it});

        total += dfa_mult(input[match_start..match_end]);
        match_start = match_end;
        it += 1;
    }
    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();
    _ = gpa;

    const p1_example_input = try openAndRead(page_allocator, "./src/day03/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day03/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_example_input = try openAndRead(page_allocator, "./src/day03/p2_example.txt");
    defer page_allocator.free(p2_example_input); // Free the allocated memory after use

    const p2_input = try openAndRead(page_allocator, "./src/day03/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(p2_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(p2_input);
    print("Part two result: {d}\n", .{result_part_two});
}
