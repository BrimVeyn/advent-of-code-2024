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

fn match(patterns: PatternMap, towel: []u8, it: usize) !bool {
    if (it >= towel.len) {
        return true;
    }

    var i = it + 1;
    while (i <= towel.len) : (i += 1) {
        const towelSlice = towel[it..i];
        if (patterns.get(towelSlice) != null) {
            const res = try match(patterns, towel, i);
            if (res) return true;
        }
    }
    return false;
}

const State = struct {
    idx: usize,
    score: usize,
};

const StateMap = std.StringHashMap(ArrayList(State));
const Entry = StateMap.Entry;

const INF = 99999999999;

fn visited(entry: ?ArrayList(State), it: usize) usize {
    if (entry) |array| {
        for (array.items) |item| {
            if (item.idx == it) return item.score;
        }
    }
    return INF;
}

fn matchTwo(alloc: Allocator, patterns: PatternMap, towel: []u8, dp: *StateMap, it: usize) !usize {
    if (it >= towel.len) {
        return 1;
    }

    var total: usize = 0;
    var i = it + 1;
    while (i <= towel.len) : (i += 1) {
        const towelSlice = towel[it..i];
        const subTotal = visited(dp.get(towelSlice), it);
        if (subTotal != INF) {
            total += subTotal;
        } else if (patterns.get(towelSlice) != null) {
            const res = try matchTwo(alloc, patterns, towel, dp, i);
            var entry = try dp.getOrPutValue(towelSlice, ArrayList(State).init(alloc));
            try entry.value_ptr.append(.{ .idx = it, .score = res });
            total += res;
        }
    }
    return total;
}

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

    var possible: usize = 0;
    for (ctx.towels.items) |towel| {
        const result = try match(ctx.patterns, towel, 0);
        possible += @as(u1, @bitCast(result));
    }

    return possible;
}

fn partTwo(alloc: Allocator, input: []u8) !usize {
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

    var totalArrangments: usize = 0;
    for (ctx.towels.items) |towel| {
        var dp = StateMap.init(alloc);
        defer {
            var it = dp.iterator();
            while (it.next()) |entry| entry.value_ptr.deinit();
            dp.deinit();
        }

        const result = try matchTwo(alloc, ctx.patterns, towel, &dp, 0);
        totalArrangments += result;
    }

    return totalArrangments;
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

    const res_real = try partOne(gpa, p1_input);
    print("Part one example result: {d}\n", .{res_real});

    const res_ex2 = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{res_ex2});

    const res_real2 = try partTwo(gpa, p1_input);
    print("Part two example result: {d}\n", .{res_real2});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
