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

const PatternMap = std.StringHashMap(bool);

const Context = struct {
    patterns: PatternMap,
    towels: ArrayList([]u8),

    pub fn init(alloc: Allocator, input: []u8) !Context {
        var blocks = std.mem.tokenizeSequence(u8, input, "\n\n");
        const patBlock = blocks.next().?;

        var patterns = PatternMap.init(alloc);
        var patIt = std.mem.tokenizeScalar(u8, patBlock, ',');
        while (patIt.next()) |it| {
            const stripped = try alloc.dupe(u8, std.mem.trimLeft(u8, it, " "));
            try patterns.put(stripped, true);
        }

        var towels = ArrayList([]u8).init(alloc);

        const towBlock = blocks.next().?;
        var towIt = std.mem.tokenizeScalar(u8, towBlock, '\n');
        while (towIt.next()) |towel| {
            try towels.append(try alloc.dupe(u8, towel));
        }

        return .{
            .patterns = patterns,
            .towels = towels,
        };
    }
};

fn partOne(alloc: Allocator, input: []u8) !usize {
    var ctx = try Context.init(alloc, input);
    defer {
        var it = ctx.patterns.iterator();
        while (it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
        }
        ctx.patterns.deinit();
        for (ctx.towels.items) |towel| alloc.free(towel);
        ctx.towels.deinit();
    }

    print("towels: {s}\n", .{ctx.towels.items});
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day19/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day19/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{res_ex});

    // const res_real = try partOne(gpa, p1_input);
    // print("Part one example result: {d}\n", .{res_real});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
