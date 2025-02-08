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
const Links = AutoHashMap(u16, ArrayList(u16));

const Keys = StringHashMap(u16);

pub fn parse(alloc: Allocator, input: []const u8) !struct { Links, Keys, u16 } {
    var links = Links.init(alloc);
    var it = std.mem.tokenizeScalar(u8, input, '\n');

    var keys = Keys.init(alloc);

    var id: u16 = 1;

    while (it.next()) |line| {
        var ids = std.mem.tokenizeScalar(u8, line, '-');
        const lhs = ids.next().?;
        const rhs = ids.next().?;

        if (!keys.contains(lhs)) {
            try keys.put(lhs, id);
            id += 1;
        }
        if (!keys.contains(rhs)) {
            try keys.put(rhs, id);
            id += 1;
        }
    }

    it.reset();
    while (it.next()) |line| {
        var ids = std.mem.tokenizeScalar(u8, line, '-');
        const lhs = ids.next().?;
        const rhs = ids.next().?;

        const lhsId = keys.get(lhs).?;
        const rhsId = keys.get(rhs).?;

        const entryLhs = try links.getOrPutValue(lhsId, ArrayList(u16).init(alloc));
        try entryLhs.value_ptr.append(rhsId);

        const entryRhs = try links.getOrPutValue(rhsId, ArrayList(u16).init(alloc));
        try entryRhs.value_ptr.append(lhsId);
    }

    return .{ links, keys, id };
}

fn lessThan(context: void, a: u16, b: u16) bool {
    _ = context;
    return (a < b);
}

const SliceMap = std.HashMap([]u16, bool, SliceContext, 60);
// const SliceMap = std.ArrayHashMap([]usize, bool, SliceContext, true);

const SliceContext = struct {
    pub fn hash(ctx: SliceContext, key: []u16) u32 {
        _ = ctx;
        var h = std.hash.Fnv1a_32.init();
        for (key) |value| {
            var bytes = std.mem.toBytes(value); // Convertit `usize` en `[std.mem.native_endian.bits / 8]u8`
            h.update(&bytes);
        }
        return h.final();
    }

    pub fn eql(ctx: SliceContext, a: []u16, b: []u16) bool {
        _ = ctx;
        if (a.len != b.len) @panic("Comparing two slices with different sizes");
        return std.mem.eql(u16, a, b);
    }

    // pub fn eql(ctx: SliceContext, a: []usize, b: []usize, _: usize) bool {
    //     _ = ctx;
    //     if (a.len != b.len) @panic("Comparing two slices with different sizes");
    //     return std.mem.eql(usize, a, b);
    // }
};

pub fn intersection(alloc: Allocator, lhs: ArrayList(u16), rhs: ArrayList(u16)) !ArrayList(u16) {
    var set = ArrayList(u16).init(alloc);
    for (lhs.items) |lv| {
        for (rhs.items) |rv| {
            if (lv == rv) {
                try set.append(lv);
            }
        }
    }
    return set;
}

pub fn findHigherGroups(alloc: Allocator, maxId: u16, trios: SliceMap) !void {
    var order: usize = 3;
    var curOrder: SliceMap = trios;
    while (true) {
        var nextOrder = SliceMap.init(alloc);

        defer {
            var it = curOrder.iterator();
            while (it.next()) |entry| {
                alloc.free(entry.key_ptr.*);
            }
            curOrder.deinit();
            curOrder = nextOrder;
        }

        defer order += 1;

        const curCount = curOrder.count();
        var counter: usize = 0;

        const placeHolder = try alloc.alloc(u16, order);
        defer alloc.free(placeHolder);

        var curIt = curOrder.iterator();
        while (curIt.next()) |entry| : (counter += 1) {
            if (counter % 1000 == 0) std.debug.print("{d}/{d}\n", .{ counter, curCount });
            outer: for (1..maxId) |id| {
                @memcpy(placeHolder, entry.key_ptr.*);
                for (0..order) |i| {
                    defer @memcpy(entry.key_ptr.*, placeHolder);
                    entry.key_ptr.*[i] = @intCast(id);
                    std.mem.sort(u16, entry.key_ptr.*[0..], {}, lessThan);
                    // print("Trying: {d}\n", .{entry.key_ptr.*});
                    if (curOrder.get(entry.key_ptr.*) == null)
                        continue :outer;
                }

                var tmp = try alloc.alloc(u16, order + 1);
                for (entry.key_ptr.*, 0..) |value, i| {
                    tmp[i] = value;
                }
                tmp[order] = @intCast(id);
                std.mem.sort(u16, tmp, {}, lessThan);
                // print("tmp: {d}\n", .{tmp});
                //
                if (nextOrder.contains(tmp)) {
                    alloc.free(tmp);
                } else {
                    try nextOrder.put(tmp, true);
                }

                // print("Match: {s}-{s}\n", .{ entry.key_ptr.*, id });
            }
        }
        if (nextOrder.count() == 1) {
            var debug = nextOrder.iterator();
            while (debug.next()) |entry| {
                print("{d}\n", .{entry.key_ptr.*});
            }
        }

        if (nextOrder.count() == 0) {
            var it = nextOrder.iterator();
            while (it.next()) |entry| {
                alloc.free(entry.key_ptr.*);
            }
            nextOrder.deinit();
            break;
        }
    }
}

pub fn partTwo(alloc: Allocator, input: []const u8) !usize {
    var links, var keys, const maxId = try parse(alloc, input);
    defer {
        var it = links.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        links.deinit();
        keys.deinit();
    }

    //Iterate over every links, compute its intersection
    var it = links.iterator();

    var trios = SliceMap.init(alloc);

    while (it.next()) |entry| {
        print("{d}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
        for (entry.value_ptr.items) |value| {
            const rhs = links.get(value).?;
            const inter = try intersection(alloc, entry.value_ptr.*, rhs);
            defer inter.deinit();
            if (inter.items.len != 0) {
                for (inter.items) |item| {
                    var final_seq = [3]u16{ entry.key_ptr.*, value, item };
                    std.sort.heap(u16, final_seq[0..], {}, lessThan);

                    const owned_seq = try alloc.dupe(u16, final_seq[0..]);

                    if (trios.contains(owned_seq)) {
                        alloc.free(owned_seq);
                    } else {
                        try trios.put(owned_seq, true);
                    }
                }
                // print("inter: {s}(){s}: {s}\n", .{ entry.key_ptr.*, value, inter.items });
            }
        }
    }

    var triosIt = trios.iterator();
    while (triosIt.next()) |entry| {
        print("{d}\n", .{entry.key_ptr.*});
        // alloc.free(entry.key_ptr.*);
    }
    // trios.deinit();

    // var keyIt = keys.iterator();
    // while (keyIt.next()) |entry| {
    //     print("{s}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    // }

    try findHigherGroups(alloc, maxId, trios);
    return 0;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

    // const oneExample = try partOne(alloc, Example);
    // print("PartOne(Example): {any}\n", .{oneExample});

    // const oneReal = try partOne(alloc, Real);
    // print("PartOne(Real): {any}\n", .{oneReal});

    // const twoExample = try partTwo(alloc, Example);
    // print("PartTwo(Example): {any}\n", .{twoExample});

    const twoReal = try partTwo(alloc, Real);
    print("PartTwo(Real): {any}\n", .{twoReal});

    const leaks = gpa.deinit();
    _ = leaks;
}
