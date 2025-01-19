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

fn getLastOccupied(arr: ArrayList(i64), last_poped: usize) usize {
    for (0..last_poped) |it| {
        if (arr.items[arr.items.len - it - 1] != -1)
            return (arr.items.len - it - 1);
    }
    return 0;
}

fn getFirstFree(arr: ArrayList(i64), last_free: usize) usize {
    for (last_free..arr.items.len - 1) |it| {
        if (arr.items[it] == -1)
            return it;
    }
    return arr.items.len;
}

fn partOne(allocator: Allocator, input: []const u8) !usize {
    var arr = ArrayList(i64).init(allocator);
    defer arr.deinit();

    var id: usize = 0;
    for (input, 0..) |ch, i| {
        if (ch < '0' or ch > '9')
            break;
        if (@mod(i, 2) == 0) {
            for (0..(ch - 48)) |_| {
                try arr.append(@intCast(id));
            }
            id += 1;
        } else {
            for (0..(ch - 48)) |_| {
                try arr.append(-1);
            }
        }
    }

    var first_free: usize = getFirstFree(arr, 0);
    var last_poped: usize = getLastOccupied(arr, arr.items.len - 1);

    while (true) {
        defer {
            first_free = getFirstFree(arr, first_free);
            last_poped = getLastOccupied(arr, last_poped);
        }
        if (last_poped <= first_free)
            break;
        std.mem.swap(i64, &arr.items[first_free], &arr.items[last_poped]);
    }

    var total: usize = 0;
    for (arr.items, 0..) |file_id, it| {
        if (file_id == -1)
            break;
        total += (@as(usize, @intCast(file_id)) * it);
    }

    return total;
}

const Block = struct {
    id: i32,
    size: usize,
};

fn printDisk(disk: ArrayList(*Block)) void {
    for (disk.items) |item| {
        for (0..item.size) |_| {
            if (item.id == -1) {
                print(".", .{});
            } else {
                print("{}", .{item.id});
            }
        }
    }
    print("\n", .{});
}

fn checksum(disk: ArrayList(*Block)) usize {
    var mul: usize = 0;
    var total: usize = 0;
    for (disk.items) |item| {
        if (item.id == -1) {
            mul += item.size;
        } else {
            for (0..item.size) |_| {
                total += (mul * @as(usize, @intCast(item.id)));
                mul += 1;
            }
        }
    }
    return total;
}

fn partTwo(allocator: Allocator, input: []const u8) !usize {
    var disk = ArrayList(*Block).init(allocator);
    defer {
        for (disk.items) |block| {
            allocator.destroy(block);
        }
        disk.deinit();
    }
    var files = ArrayList(*Block).init(allocator);
    defer files.deinit();

    var id: usize = 0;
    for (input, 0..) |ch, i| {
        if (ch < '0' or ch > '9')
            break;
        const blockSize: usize = (ch - '0');
        if (@mod(i, 2) == 0) {
            const block = try allocator.create(Block);
            block.* = .{ .id = @intCast(id), .size = blockSize };
            try disk.append(block);
            try files.append(block);
            id += 1;
        } else {
            const block = try allocator.create(Block);
            block.* = .{ .id = -1, .size = blockSize };
            try disk.append(block);
        }
    }

    // printDisk(disk);

    for (0..files.items.len - 1) |i| {
        var file = files.items[files.items.len - 1 - i];

        for (0..disk.items.len - 1) |j| {
            var free = disk.items[j];
            // print("try: {d} at {d}\n", .{ file.id, j });

            if (free.id == file.id)
                break;

            if (free.id == -1) {
                if (file.size > free.size)
                    continue;

                if (free.size == file.size) {
                    free.id = file.id;
                    file.id = -1;
                } else if (file.size < free.size) {
                    const remain = try allocator.create(Block);
                    remain.* = Block{ .id = -1, .size = free.size - file.size };
                    free.id = file.id;
                    free.size = file.size;
                    file.id = -1;
                    try disk.insert(j + 1, remain);
                }
                break;
            }
        }
    }
    // printDisk(disk);

    return checksum(disk);
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day09/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day09/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day09/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
