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
const Links = StringArrayHashMap(ArrayList(Id));

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

fn lessThan(context: void, a: Id, b: Id) bool {
    _ = context;
    if (a[0] < b[0]) return true;
    if (a[0] == b[0] and a[1] < b[1]) return true;
    return false;
}

const SliceContext = struct {
    pub fn hash(ctx: SliceContext, key: []Id) u32 {
        _ = ctx;
        var h = std.hash.Fnv1a_32.init();
        for (0..key.len) |i| {
            h.update(key[i]);
        }
        return h.final();
    }

    pub fn eql(ctx: SliceContext, a: []Id, b: []Id, _: usize) bool {
        _ = ctx;
        if (a.len != b.len) @panic("Comparing two slices with different sizes");
        for (0..a.len) |i| {
            if (!std.mem.eql(u8, a[i], b[i])) {
                return false;
            }
        }
        return true;
    }
};

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

pub fn partOne(alloc: Allocator, input: []const u8) !usize {
    var links = try parse(alloc, input);
    defer {
        var it = links.iterator();
        while (it.next()) |entry| entry.value_ptr.deinit();
        links.deinit();
    }

    var it = links.iterator();

    var trios = Intersections.init(alloc);
    defer {
        // var tIt = trios.iterator();
        // while (tIt.next()) |entry| {
        //     alloc.free(entry.key_ptr.*);
        // }

        trios.deinit();
    }

    var visited = SliceMap.init(alloc);
    defer visited.deinit();

    while (it.next()) |entry| {
        print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
        for (entry.value_ptr.items) |value| {
            const rhs = links.get(value).?;

            var couple = [2]Id{ entry.key_ptr.*, value };
            std.mem.sort(Id, couple[0..], {}, lessThan);

            const matchVisited = try visited.getOrPutValue(couple[0..], true);
            if (matchVisited.found_existing)
                continue;

            const inter = try intersection(alloc, entry.value_ptr.*, rhs);
            defer inter.deinit();

            if (inter.items.len != 0) {
                for (inter.items) |item| {
                    var final_seq = [2]Id{ value, item };
                    // const key = entry.key_ptr.*;
                    // const newValue = [2]Id{ value, item };
                    //
                    // print("Trio: {s}: {s}\n", .{ key, newValue });
                    // if (final_seq[0][0] == 't' or
                    //     final_seq[1][0] == 't' or
                    //     final_seq[2][0] == 't')
                    // {
                    std.mem.sort(Id, final_seq[0..], {}, lessThan);
                    const owned_seq = try alloc.dupe(Id, final_seq[0..]);

                    const match = try trios.getOrPutValue(entry.key_ptr.*, SliceMap.init(alloc));
                    const matchInner = try match.value_ptr.getOrPutValue(owned_seq, true);
                    if (matchInner.found_existing)
                        alloc.free(owned_seq);
                    // }
                }
            }
        }
    }

    var triosIt = trios.iterator();
    while (triosIt.next()) |entry| {
        // print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.keys() });
        var valueIt = entry.value_ptr.iterator();
        while (valueIt.next()) |values| {
            alloc.free(values.key_ptr.*);
        }
        entry.value_ptr.deinit();
    }

    return trios.count();
}

const SliceMap = std.ArrayHashMap([]Id, bool, SliceContext, true);
const Intersections = StringArrayHashMap(std.ArrayHashMap([]Id, bool, SliceContext, true));

pub fn findHigherGroups(alloc: Allocator, ids: []Id, trios: SliceMap) !usize {
    var order: usize = 3;
    var curOrder = trios;
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

        var curIt = curOrder.iterator();
        const curCount = curOrder.count();
        var iiii: usize = 0;
        while (curIt.next()) |entry| : (iiii += 1) {
            print("{d}/{d}\n", .{ iiii, curCount });
            outer: for (ids) |id| {
                for (0..order) |i| {
                    var conTest = try alloc.dupe(Id, entry.key_ptr.*);
                    defer alloc.free(conTest);
                    conTest[i] = id;
                    std.mem.sort(Id, conTest[0..], {}, lessThan);
                    if (curOrder.get(conTest) != null) {} else {
                        continue :outer;
                    }
                }
                var tmp = ArrayList(Id).init(alloc);
                defer tmp.deinit();

                for (0..entry.key_ptr.len) |i| try tmp.append(entry.key_ptr.*[i]);
                try tmp.append(id);
                std.mem.sort(Id, tmp.items[0..], {}, lessThan);
                // print("tmp: {s}\n", .{tmp.items});

                const tmpAsSlice = try tmp.toOwnedSlice();
                const match = try nextOrder.getOrPutValue(tmpAsSlice, true);
                if (match.found_existing)
                    alloc.free(tmpAsSlice);

                // print("Match: {s}-{s}\n", .{ entry.key_ptr.*, id });
            }
        }
        // var debug = nextOrder.iterator();
        // while (debug.next()) |entry| {
        //     print("{s}\n", .{entry.key_ptr.*});
        // }

        if (nextOrder.count() == 0) {
            var it = nextOrder.iterator();
            while (it.next()) |entry| {
                alloc.free(entry.key_ptr.*);
            }
            nextOrder.deinit();
            break;
        }
    }
    return 1;
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

    var trios = SliceMap.init(alloc);

    while (it.next()) |entry| {
        print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.items });
        for (entry.value_ptr.items) |value| {
            const rhs = links.get(value).?;
            const inter = try intersection(alloc, entry.value_ptr.*, rhs);
            defer inter.deinit();
            if (inter.items.len != 0) {
                for (inter.items) |item| {
                    var final_seq = [3]Id{ entry.key_ptr.*, value, item };
                    std.sort.heap(Id, final_seq[0..], {}, lessThan);

                    const owned_seq = try alloc.dupe(Id, final_seq[0..]);

                    const match = try trios.getOrPutValue(owned_seq, true);
                    if (match.found_existing)
                        alloc.free(owned_seq);
                }
                // print("inter: {s}(){s}: {s}\n", .{ entry.key_ptr.*, value, inter.items });
            }
        }
    }

    var triosIt = trios.iterator();
    while (triosIt.next()) |entry| {
        print("{s}\n", .{entry.key_ptr.*});
    }

    const result = try findHigherGroups(alloc, links.keys(), trios);
    _ = result;

    return 0;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = gpa.allocator();

    // const oneExample = try partOne(alloc, Example);
    // print("PartOne(Example): {any}\n", .{oneExample});

    const oneReal = try partOne(alloc, Real);
    print("PartOne(Real): {any}\n", .{oneReal});

    // const twoExample = try partTwo(alloc, Example);
    // print("PartTwo(Example): {any}\n", .{twoExample});

    // const twoReal = try partTwo(alloc, Real);
    // print("PartTwo(Real): {any}\n", .{twoReal});

    const leaks = gpa.deinit();
    _ = leaks;
}
