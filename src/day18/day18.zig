const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const uVec2 = @Vector(2, usize);
const iVec2 = @Vector(2, i32);

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Context = struct {
    mapSize: usize,
    memory: ArrayList(struct { u64, u64 }),
    maze: [][]u8,

    pub fn init(alloc: Allocator, input: []u8, mapSize: usize) !Context {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var memory = ArrayList(struct { u64, u64 }).init(alloc);

        while (it.next()) |line| {
            const virPos = std.mem.indexOf(u8, line, ",").?;
            const x = try std.fmt.parseInt(u64, line[0..virPos], 10);
            const y = try std.fmt.parseInt(u64, line[virPos + 1 ..], 10);
            try memory.append(.{ x, y });
        }

        var map = try ArrayList([]u8).initCapacity(alloc, mapSize);
        for (0..mapSize) |_| {
            var line = try ArrayList(u8).initCapacity(alloc, mapSize);
            line.appendNTimesAssumeCapacity('.', mapSize);
            map.appendAssumeCapacity(try line.toOwnedSlice());
        }
        const maze = try map.toOwnedSlice();

        return .{
            .memory = memory,
            .mapSize = mapSize,
            .maze = maze,
        };
    }
};

fn partOne(alloc: Allocator, input: []u8, mapSize: usize) !usize {
    var ctx = try Context.init(alloc, input, mapSize);
    defer {
        ctx.memory.deinit();
        for (ctx.maze) |line| alloc.free(line);
        alloc.free(ctx.maze);
    }

    print("{any}\n", .{ctx.memory.items});

    for (ctx.maze) |line| print("{s}\n", .{line});

    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day18/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day18/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input, 6);
    print("Part one example result: {d}\n", .{res_ex});

    // const res_real = try partOne(gpa, p1_input, 70);
    // print("Part one example result: {d}\n", .{res_real});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p1_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
