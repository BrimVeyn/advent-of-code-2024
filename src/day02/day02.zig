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

fn parseFile(allocator: Allocator, input: []const u8) !ArrayList(ArrayList(i32)) {
    var array = ArrayList(ArrayList(i32)).init(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var nums = std.mem.splitScalar(u8, line, ' ');
        var line_array = ArrayList(i32).init(allocator);
        while (nums.next()) |num_str| {
            const num = try std.fmt.parseInt(i32, num_str, 10);
            try line_array.append(num);
        }
        try array.append(line_array);
    }
    return array;
}

fn partOne(allocator: Allocator, input: []const u8) !i32 {
    const array = try parseFile(allocator, input);
    defer array.deinit();

    var total_safe: i32 = 0;
    for (0..array.items.len) |it| {
        const first_item = array.items[it].items[0];
        const second_item = array.items[it].items[1];
        const order: i32 = if (first_item > second_item) 1 else -1;
        for (0..array.items[it].items.len) |inner_it| {
            if (inner_it == array.items[it].items.len - 1) {
                total_safe += 1;
                break;
            }
            const current = array.items[it].items[inner_it];
            const next = array.items[it].items[inner_it + 1];
            const diff: i32 = @intCast(@abs(current - next));
            if (diff < 1 or diff > 3)
                break;
            if ((order == 1 and current < next) or (order == -1 and current > next))
                break;
        }
    }
    return total_safe;
}

fn partTwo(allocator: Allocator, input: []const u8) !i32 {
    const data = try parseFile(allocator, input);
    defer data.deinit();

    var total_safe: i32 = 0;

    for (0..data.items.len) |it| {
        var order: i32 = 0;
        var tolerance: i32 = 0;

        print("-------- line {} --------\n", .{it});
        var inner_it: usize = 0;
        while (inner_it < data.items[it].items.len) {
            print("item: {}, tolerance: {}\n", .{ data.items[it].items[inner_it], tolerance });
            if (tolerance > 1)
                break;

            if (inner_it == data.items[it].items.len - 1) {
                total_safe += 1;
                break;
            }

            const current = data.items[it].items[inner_it];
            const next = data.items[it].items[inner_it + 1];

            if (inner_it <= 1) {
                order = if (current > next) 1 else -1;
            }
            inner_it += 1;

            const diff: i32 = @intCast(@abs(current - next));
            if (diff < 1 or diff > 3) {
                _ = data.items[it].orderedRemove(inner_it - 1);
                tolerance += 1;
                inner_it -= 1;
            }

            if ((order == 1 and current < next) or (order == -1 and current > next)) {
                _ = data.items[it].orderedRemove(inner_it - 1);
                tolerance += 1;
                inner_it -= 1;
            }
        }
        print("Safe : {}\n", .{if (tolerance > 1) false else true});
    }
    return total_safe;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const example_input = try openAndRead(page_allocator, "./src/day02/p1_example.txt");
    defer page_allocator.free(example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day02/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day02/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const result_example = try partTwo(gpa, example_input);
    print("Part two result: {d}\n", .{result_example});
}
