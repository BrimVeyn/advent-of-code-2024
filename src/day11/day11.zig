const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(allocator: Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

fn hasEvenDigits(n: u64) bool {
    const digitCount = std.math.log10_int(n) + 1;

    return (digitCount % 2 == 0);
}

fn blink(stone: u64) !struct { u64, ?u64 } {
    var rhs: ?u64 = null;
    var lhs: u64 = stone;
    if (stone == 0) {
        lhs = 1;
    } else if (hasEvenDigits(stone)) {
        var buffer: [100]u8 = .{0} ** 100;
        const stone_str = try std.fmt.bufPrint(&buffer, "{d}", .{stone});
        lhs = try std.fmt.parseInt(u64, stone_str[0 .. stone_str.len / 2], 10);
        rhs = try std.fmt.parseInt(u64, stone_str[stone_str.len / 2 ..], 10);
    } else {
        lhs *= 2024;
    }
    return .{ lhs, rhs };
}

fn partOne(allocator: Allocator, input: []u8, iterations: usize) !usize {
    var stones = AutoArrayHashMap(u64, usize).init(allocator);
    defer stones.deinit();

    var it = std.mem.tokenizeScalar(u8, input[0 .. input.len - 1], ' ');
    while (it.next()) |stone| {
        // print("stone: |{s}|\n", .{stone});
        try stones.put(try std.fmt.parseInt(u64, stone, 10), 1);
    }

    var arena_allocator: std.heap.ArenaAllocator = .init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    for (0..iterations) |_| {
        var it_stones = AutoArrayHashMap(u64, usize).init(arena);
        defer _ = arena_allocator.reset(.retain_capacity);

        var stone_it = stones.iterator();

        while (stone_it.next()) |entry| {
            if (entry.value_ptr.* == 0)
                continue;

            const lhs, const maybe_rhs = try blink(entry.key_ptr.*);

            const lhs_entry = try it_stones.getOrPutValue(lhs, entry.value_ptr.*);
            if (lhs_entry.found_existing)
                lhs_entry.value_ptr.* += entry.value_ptr.*;

            if (maybe_rhs) |rhs| {
                const rhs_entry = try it_stones.getOrPutValue(rhs, entry.value_ptr.*);
                if (rhs_entry.found_existing)
                    rhs_entry.value_ptr.* += entry.value_ptr.*;
            }
        }
        stones.deinit();
        stones = try it_stones.cloneWithAllocator(allocator);
        // print("------IT: {d}-----\n", .{iteration});
        // var tit = stones.iterator();
        // while (tit.next()) |entry| {
        //     print("{}: {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        // }
    }

    var stoneCount: usize = 0;
    var tit = stones.iterator();
    while (tit.next()) |entry| {
        stoneCount += entry.value_ptr.*;
    }

    return stoneCount;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day11/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day11/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input, 25);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input, 25);
    print("Part one result: {d}\n", .{result_part_one});

    const result_part_two_example = try partOne(gpa, p1_example_input, 75);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partOne(gpa, p1_input, 75);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
