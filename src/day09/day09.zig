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

const File = struct {
    id: usize,
    size: usize,
};

const DiskMapType = union(enum) {
    free: usize,
    file: File,
};

const FileSystem = struct {
    diskMap: ArrayList(DiskMapType),
    movedMap: AutoHashMap(usize, bool),
    holeIt: usize,
    fileIt: usize,

    pub fn init(allocator: Allocator, input: []const u8) !FileSystem {
        var diskMap = ArrayList(DiskMapType).init(allocator);
        const movedMap = AutoHashMap(usize, bool).init(allocator);

        var id: usize = 0;
        for (input, 0..) |ch, i| {
            if (ch < '0' or ch > '9')
                break;
            const segmentSize = (ch - '0');
            if (@mod(i, 2) == 0) {
                try diskMap.append(DiskMapType{ .file = .{ .id = id, .size = segmentSize } });
                id += 1;
            } else {
                try diskMap.append(DiskMapType{ .free = segmentSize });
            }
        }
        return .{
            .diskMap = diskMap,
            .movedMap = movedMap,
            .holeIt = 0,
            .fileIt = diskMap.items.len - 1,
        };
    }

    pub fn swapFile(self: *FileSystem) !void {
        if (self.diskMap.items[self.holeIt].free == self.diskMap.items[self.fileIt].file.size) {
            std.mem.swap(DiskMapType, &self.diskMap.items[self.holeIt], &self.diskMap.items[self.fileIt]);
        } else if (self.diskMap.items[self.holeIt].free > self.diskMap.items[self.fileIt].file.size) {
            self.diskMap.items[self.holeIt].free -= self.diskMap.items[self.fileIt].file.size;
            const tmp = self.diskMap.items[self.fileIt];
            self.diskMap.items[self.fileIt] = DiskMapType{ .free = tmp.file.size };
            try self.diskMap.insert(self.holeIt, tmp);
            _ = self.holeNext();
        }
        return;
    }

    pub fn getDisk(self: FileSystem, idx: usize) ?DiskMapType {
        if (idx < self.diskMap.items.len) {
            return self.diskMap.items[idx];
        } else {
            return null;
        }
    }

    pub fn nextHole(self: *FileSystem) ?DiskMapType {
        self.fileIt +%= 1;
        while (true) {
            const value = self.getDisk(self.holeIt) orelse return null;
            switch (value) {
                .file => {},
                .free => return value,
            }
            self.holeIt += 1;
        }
    }

    pub fn nextFile(self: *FileSystem) ?DiskMapType {
        self.fileIt -%= 1;
        while (true) {
            const value = self.getDisk(self.fileIt) orelse return null;
            switch (value) {
                .file => if (self.movedMap.get(value.file.id) == null) return value,
                .free => {},
            }
            self.fileIt -= 1;
        }
    }

    pub fn deinit(self: *FileSystem) void {
        self.diskMap.deinit();
        self.movedMap.deinit();
    }

    pub fn printDiskMap(self: FileSystem) void {
        print("DiskMap:", .{});
        for (self.diskMap.items) |value| {
            switch (value) {
                .file => print("[F{}|{}],", .{ value.file.id, value.file.size }),
                .free => print("[H{}],", .{value.free}),
            }
        }
        print("\n", .{});
    }

    pub fn printString(self: FileSystem, allocator: Allocator) !void {
        var buf = ArrayList(u8).init(allocator);
        defer buf.deinit();
        for (self.diskMap.items) |item| {
            switch (item) {
                .file => {
                    for (0..item.file.size) |_| {
                        var buffer: [50]u8 = .{0} ** 50;
                        const res_str = try std.fmt.bufPrint(&buffer, "{d}", .{item.file.id});
                        try buf.appendSlice(res_str);
                    }
                },
                .free => {
                    for (0..item.free) |_| {
                        try buf.append('.');
                    }
                },
            }
        }
        print("str: {s}\n", .{buf.items});
    }
};

fn partTwo(allocator: Allocator, input: []const u8) !usize {
    var fs = try FileSystem.init(allocator, input);
    defer fs.deinit();

    fs.printDiskMap();

    while (true) {
        if (fs.nextFile()) |entry| {
            std.debug.print("Processing entry: {any}\n", .{entry});
        } else {
            break; // No more entries.
        }
    }

    fs.printDiskMap();

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

    // const p2_input = try openAndRead(page_allocator, "./src/day09/p1_input.txt");
    // defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}

// 2333133121414131402

// 00777111...222633354.................
// 00...111...222.333...4..5....6....777
