const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const StringArrayHashMap = std.StringArrayHashMap;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;
const uVec2 = @Vector(2, usize);
const iVec2 = @Vector(2, i32);

const Example = @embedFile("example.txt");
const Real = @embedFile("real.txt");

const Id = []const u8;
const Links = StringHashMap(ArrayList(Id));

pub fn parse(alloc: Allocator, input: []const u8) !Links {
    var links = Links.init(alloc);
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        var ids = std.mem.tokenizeScalar(u8, line, '-');
        const lhs = ids.next().?;
        const rhs = ids.next().?;

        const entryLhs = try links.getOrPutValue(lhs, ArrayList(Id).init(alloc));
        try entryLhs.value_ptr.append(rhs);

        const entryRhs = try links.getOrPutValue(rhs, ArrayList(Id).init(alloc));
        try entryRhs.value_ptr.append(lhs);
    }

    return links;
}

pub fn intersection(alloc: Allocator, lhs: ArrayList(Id), rhs: ArrayList(Id)) !ArrayList(Id) {
    var set = ArrayList(Id).init(alloc);
    for (lhs.items) |lv| {
        for (rhs.items) |rv| {
            if (std.mem.eql(u8, lv, rv)) {
                try set.append(lv);
            }
        }
    }
    return set;
}

fn lessThan(context: void, a: Id, b: Id) bool {
    _ = context;
    if (a[0] < b[0]) return true;
    if (a[0] == b[0] and a[1] < b[1]) return true;
    return false;
}

const TrioContext = struct {
    pub fn hash(ctx: TrioContext, key: [3]Id) u32 {
        _ = ctx;
        var h = std.hash.Fnv1a_32.init();
        h.update(key[0]);
        h.update(key[1]);
        h.update(key[2]);
        return h.final();
    }

    pub fn eql(ctx: TrioContext, a: [3]Id, b: [3]Id, _: usize) bool {
        _ = ctx;
        return std.mem.eql(u8, a[0], b[0]) and std.mem.eql(u8, a[1], b[1]) and std.mem.eql(u8, a[2], b[2]);
    }
};

pub fn partOne(alloc: Allocator, input: []const u8) !usize {
    var links = try parse(alloc, input);
    defer {
        var it = links.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        links.deinit();
    }

    //Iterate over every links, compute its intersection
    var it = links.iterator();

    var trios = std.ArrayHashMap([3]Id, bool, TrioContext, true).init(alloc);
    defer trios.deinit();

    while (it.next()) |entry| {
        print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
        for (entry.value_ptr.items) |value| {
            const rhs = links.get(value).?;
            const inter = try intersection(alloc, entry.value_ptr.*, rhs);
            defer inter.deinit();
            if (inter.items.len != 0) {
                for (inter.items) |item| {
                    var final_seq = [3]Id{ entry.key_ptr.*, value, item };
                    if (final_seq[0][0] == 't' or
                        final_seq[1][0] == 't' or
                        final_seq[2][0] == 't')
                    {
                        // print("UnSorted: {s}\n", .{final_seq});
                        std.sort.heap(Id, final_seq[0..], {}, lessThan);
                        // print("Sorted: {s}\n", .{final_seq});
                        try trios.put(final_seq, true);
                        // print("inter: {s}(){s}: {s}\n", .{ entry.key_ptr.*, value, inter.items });
                    }
                }
            }
            // trios += inter.items.len;
        }
    }

    var triosIt = trios.iterator();
    while (triosIt.next()) |entry| {
        print("{s}\n", .{entry.key_ptr.*});
    }

    return trios.count();
}

pub fn partTwo(alloc: Allocator, input: []const u8) !usize {
    var links = try parse(alloc, input);
    defer {
        var it = links.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        links.deinit();
    }

    //Iterate over every links, compute its intersection
    var it = links.iterator();

    var trios = std.ArrayHashMap([3]Id, bool, TrioContext, true).init(alloc);
    defer trios.deinit();

    while (it.next()) |entry| {
        print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
        for (entry.value_ptr.items) |value| {
            const rhs = links.get(value).?;
            const inter = try intersection(alloc, entry.value_ptr.*, rhs);
            defer inter.deinit();
            if (inter.items.len != 0) {
                for (inter.items) |item| {
                    var final_seq = [3]Id{ entry.key_ptr.*, value, item };
                    // print("UnSorted: {s}\n", .{final_seq});
                    std.sort.heap(Id, final_seq[0..], {}, lessThan);
                    // print("Sorted: {s}\n", .{final_seq});
                    try trios.put(final_seq, true);
                    // print("inter: {s}(){s}: {s}\n", .{ entry.key_ptr.*, value, inter.items });
                }
            }
            // trios += inter.items.len;
        }
    }

    var triosIt = trios.iterator();
    while (triosIt.next()) |entry| {
        print("{s}\n", .{entry.key_ptr.*});
    }

    return trios.count();
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

    // const oneExample = try partOne(alloc, Example);
    // print("PartOne(Example): {any}\n", .{oneExample});

    // const oneReal = try partOne(alloc, Real);
    // print("PartOne(Real): {any}\n", .{oneReal});

    const twoExample = try partTwo(alloc, Example);
    print("PartTwo(Example): {any}\n", .{twoExample});
    //
    // const twoReal = try partTwo(alloc, Real);
    // print("PartTwo(Real): {any}\n", .{twoReal});

    const leaks = gpa.deinit();
    _ = leaks;
}
