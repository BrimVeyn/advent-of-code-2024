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

const Links = AutoHashMap(u16, ArrayList(u16));
const StringToId = StringArrayHashMap(u16);
const IdArray = ArrayList(u16);

pub fn parse(alloc: Allocator, input: []const u8) !struct { Links, StringToId, IdArray } {
    var links = Links.init(alloc);
    var it = std.mem.tokenizeScalar(u8, input, '\n');

    var keys = StringToId.init(alloc);
    var idArray = IdArray.init(alloc);

    while (it.next()) |line| {
        var ids = std.mem.tokenizeScalar(u8, line, '-');
        const lhs = ids.next().?;
        const rhs = ids.next().?;

        if (!keys.contains(lhs)) {
            const lhsId = @as(u16, (@as(u16, @intCast(lhs[0])) << @as(u4, 8)) + @as(u16, @intCast(lhs[1])));
            try keys.put(lhs, lhsId);
            try idArray.append(lhsId);
        }
        if (!keys.contains(rhs)) {
            const rhsId = @as(u16, (@as(u16, @intCast(rhs[0])) << @as(u4, 8)) + @as(u16, @intCast(rhs[1])));
            try keys.put(rhs, rhsId);
            try idArray.append(rhsId);
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

    var itLinks = links.valueIterator();
    while (itLinks.next()) |tab| {
        std.mem.sort(u16, tab.items, {}, std.sort.asc(u16));
    }

    return .{ links, keys, idArray };
}

fn lessThan(context: void, a: u16, b: u16) bool {
    _ = context;
    return (a < b);
}

const SliceMap = std.ArrayHashMap([]u16, bool, SliceContext, true);

const SliceContext = struct {
    pub fn hash(ctx: SliceContext, key: []u16) u32 {
        _ = ctx;
        var h = std.hash.Fnv1a_32.init();
        for (key) |value| {
            var bytes = std.mem.toBytes(value);
            h.update(&bytes);
        }
        return h.final();
    }

    pub fn eql(ctx: SliceContext, a: []u16, b: []u16, _: usize) bool {
        _ = ctx;
        return std.mem.eql(u16, a, b);
    }
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

pub fn orderU16(context: u16, item: u16) std.math.Order {
    return (std.math.order(context, item));
}

pub fn findHigherGroups(alloc: Allocator, idArray: IdArray, trios: SliceMap, links: Links) !SliceMap {
    var order: usize = 3;
    var curOrder: SliceMap = trios;

    while (true) {
        var nextOrder = SliceMap.init(alloc);

        defer {
            for (curOrder.keys()) |key| alloc.free(key);
            curOrder.deinit();
            curOrder = nextOrder;
            order += 1;
        }

        const setTest = try alloc.alloc(u16, order + 1);
        defer alloc.free(setTest);

        // const total = curOrder.count();

        for (curOrder.keys()) |key| {
            // if (counter % 1000 == 0) print("{d}/{d}\n", .{ counter, total });
            outer: for (idArray.items) |id| {
                check: for (key) |target| {
                    const connections = links.get(target).?;
                    if (std.sort.binarySearch(u16, connections.items, @as(u16, @intCast(id)), orderU16) != null)
                        continue :check;
                    continue :outer;
                }

                std.mem.copyForwards(u16, setTest, key);
                setTest[order] = @intCast(id);
                std.mem.sort(u16, setTest, {}, lessThan);

                if (nextOrder.contains(setTest))
                    continue :outer;

                try nextOrder.put(try alloc.dupe(u16, setTest), true);
            }
        }
        if (nextOrder.count() == 1) {
            return nextOrder;
        }
    }
}

fn lessThanStr(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    return std.mem.order(u8, a, b).compare(std.math.CompareOperator.lt);
}

pub fn partTwo(alloc: Allocator, input: []const u8) !usize {
    var links, var keys, const idArray = try parse(alloc, input);
    defer {
        var it = links.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        links.deinit();
        keys.deinit();
        idArray.deinit();
    }

    //Iterate over every links, compute its intersection
    var it = links.iterator();

    var trios = SliceMap.init(alloc);

    while (it.next()) |entry| {
        // print("{d}: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.items });

        var tmpSet: [3]u16 = undefined;
        for (entry.value_ptr.items) |value| {
            const rhs = links.get(value).?;
            const inter = try intersection(alloc, entry.value_ptr.*, rhs);
            defer inter.deinit();

            if (inter.items.len == 0)
                continue;

            for (inter.items) |item| {
                tmpSet = [3]u16{ entry.key_ptr.*, value, item };
                std.mem.sort(u16, tmpSet[0..], {}, lessThan);

                if (trios.contains(tmpSet[0..]))
                    continue;
                try trios.put(try alloc.dupe(u16, tmpSet[0..]), true);
            }
        }
    }

    var result = try findHigherGroups(alloc, idArray, trios, links);
    defer {
        for (result.keys()) |entry| alloc.free(entry);
        result.deinit();
    }

    for (result.keys()) |set| {
        for (0..set.len - 1) |setIt| {
            print("{c}{c},", .{ @as(u8, @intCast(set[setIt] >> 8)), @as(u8, @intCast(set[setIt] & 255)) });
        }
        print("{c}{c}\n", .{ @as(u8, @intCast(set[set.len - 1] >> 8)), @as(u8, @intCast(set[set.len - 1] & 255)) });
    }

    return 0;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

    // const twoExample = try partTwo(alloc, Example);
    // print("PartTwo(Example): {any}\n", .{twoExample});

    const twoReal = try partTwo(alloc, Real);
    print("PartTwo(Real): {any}\n", .{twoReal});

    const leaks = gpa.deinit();
    _ = leaks;
}
