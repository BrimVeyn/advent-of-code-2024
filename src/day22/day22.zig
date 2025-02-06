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

const Example = @embedFile("example.txt");
const Real = @embedFile("real.txt");

pub fn parse(alloc: Allocator, input: []const u8) !ArrayList(usize) {
    var lines = ArrayList(usize).init(alloc);

    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        try lines.append(try std.fmt.parseInt(usize, line, 10));
    }
    return lines;
}

pub fn evolve(prev: usize) usize {
    var secret = prev;
    const mul = secret << 6;
    secret = mul ^ secret;
    secret = @mod(secret, 16777216);

    const div = secret >> 5;
    secret = div ^ secret;
    secret = @mod(secret, 16777216);

    const mul2 = secret << 11;
    secret = mul2 ^ secret;
    secret = @mod(secret, 16777216);

    return secret;
}

pub fn partOne(alloc: Allocator, input: []const u8) !usize {
    const secrets = try parse(alloc, input);
    defer secrets.deinit();

    var total: usize = 0;

    for (secrets.items) |secret| {
        print("Secret: {d}\n", .{secret});
        var tmp = secret;
        for (0..2000) |_| {
            tmp = evolve(tmp);
        }
        print("After 2000 iterations: {d}\n", .{tmp});
        total += tmp;
    }

    return total;
}

const Vec4 = @Vector(4, i5);

pub fn partTwo(alloc: Allocator, input: []const u8) !usize {
    const secrets = try parse(alloc, input);
    defer secrets.deinit();

    var sequences = AutoArrayHashMap(Vec4, usize).init(alloc);
    defer sequences.deinit();

    for (secrets.items) |secret| {
        var tmp = secret;
        var diffs = ArrayList(i5).init(alloc);
        defer diffs.deinit();
        // print("Secret: {d}\n", .{secret});

        var visited = AutoArrayHashMap(Vec4, bool).init(alloc);
        defer visited.deinit();

        for (0..2000) |i| {
            const prev = tmp;
            tmp = evolve(tmp);
            const price: i5 = @intCast(@mod(tmp, 10));
            try diffs.append(price - @as(i5, @intCast(@mod(prev, 10))));
            if (i >= 3) {
                const seq: Vec4 = .{ diffs.items[i - 3], diffs.items[i - 2], diffs.items[i - 1], diffs.items[i] };
                if (visited.get(seq) == null) {
                    const entry = try sequences.getOrPutValue(seq, 0);
                    entry.value_ptr.* += @intCast(price);
                    try visited.put(seq, true);
                }
            }
        }
        // print("After 2000 iterations: {d}\n", .{tmp});
    }

    var it = sequences.iterator();
    var i: usize = 0;
    // const no = sequences.count();

    var bananas: usize = 0;

    while (it.next()) |entry| : (i += 1) {
        // print("Seq {d}/{d}: {d} --> {d}\n", .{ i, no, entry.key_ptr.*, entry.value_ptr.items });
        if (entry.value_ptr.* > bananas) bananas = entry.value_ptr.*;
    }
    print("Entry count: {d}\n", .{sequences.count()});

    return bananas;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

    // const oneExample = try partOne(alloc, Example);
    // print("PartOne(Example): {any}\n", .{oneExample});
    //
    // const oneReal = try partOne(alloc, Real);
    // print("PartOne(Real): {any}\n", .{oneReal});

    const twoExample = try partTwo(alloc, Example);
    print("PartTwo(Example): {any}\n", .{twoExample});

    const twoReal = try partTwo(alloc, Real);
    print("PartTwo(Real): {any}\n", .{twoReal});

    const leaks = gpa.deinit();
    _ = leaks;
}
