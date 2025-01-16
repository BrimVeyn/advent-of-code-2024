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

    var checksum: usize = 0;
    for (arr.items, 0..) |file_id, it| {
        if (file_id == -1)
            break;
        checksum += (@as(usize, @intCast(file_id)) * it);
    }

    return checksum;
}

const FileSystem = struct {
    idBySize: AutoHashMap(usize, ArrayList(usize)),
    freeSpaces: ArrayList(usize),
    files: ArrayList(usize),
    nbFiles: usize,

    pub fn init(allocator: Allocator, input: []const u8) !FileSystem {
        var map = AutoHashMap(usize, ArrayList(usize)).init(allocator);
        var frees = ArrayList(usize).init(allocator);
        var files = ArrayList(usize).init(allocator);

        var id: usize = 0;
        for (input, 0..) |ch, i| {
            if (ch < '0' or ch > '9')
                break;
            if (@mod(i, 2) == 0) {
                const fileSize: usize = (ch - 48);
                var entry = try map.getOrPutValue(fileSize, ArrayList(usize).init(allocator));
                try entry.value_ptr.append(id);
                try files.append(fileSize);
                id += 1;
            } else {
                try frees.append((ch - 48));
            }
        }
        return .{
            .idBySize = map,
            .freeSpaces = frees,
            .nbFiles = id,
            .files = files,
        };
    }

    pub fn deinit(self: *FileSystem) void {
        var it = self.idBySize.iterator();

        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.idBySize.deinit();
        self.freeSpaces.deinit();
    }
};

fn partTwo(allocator: Allocator, input: []const u8) !usize {
    var fs = try FileSystem.init(allocator, input);
    defer fs.deinit();

    var it = fs.idBySize.iterator();

    while (it.next()) |entry| {
        print("size: {d}, {any}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
    }

    print("Frees: {any}\n", .{fs.freeSpaces.items});

    print("Files: {d}\n", .{fs.nbFiles});
    // while ()

    var nbFiles: usize = 0;
    while (nbFiles > 0) {}
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day09/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day09/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    // const result_part_one_example = try partOne(gpa, p1_example_input);
    // print("Part one example result: {d}\n", .{result_part_one_example});
    //
    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});

    // const p2_input = try openAndRead(page_allocator, "./src/day09/p2_input.txt");
    // defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
