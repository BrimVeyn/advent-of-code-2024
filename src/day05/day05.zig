const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(allocator: Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

fn splitLine(allocator: Allocator, input: []const u8) !ArrayList([]const u8) {
    var array = ArrayList([]const u8).init(allocator);
    var splits = std.mem.splitScalar(u8, input, '\n');
    while (splits.next()) |line| {
        try array.append(line);
    }
    return array;
}

fn getUpdates(allocator: Allocator, input: [][]const u8) !ArrayList(ArrayList(i32)) {
    var updates = ArrayList(ArrayList(i32)).init(allocator);
    for (input) |line| {
        var list = ArrayList(i32).init(allocator);
        var tokens = std.mem.tokenizeScalar(u8, line, ',');
        while (tokens.next()) |token| {
            const num = try std.fmt.parseInt(i32, token, 10);
            try list.append(num);
        }
        try updates.append(list);
    }
    return updates;
}

fn getRules(allocator: Allocator, input: [][]const u8) !AutoHashMap(i32, ArrayList(i32)) {
    var map = std.AutoHashMap(i32, ArrayList(i32)).init(allocator);
    for (input) |line| {
        var pair = std.mem.tokenizeScalar(u8, line, '|');
        const value = try std.fmt.parseInt(i32, pair.next().?, 10);
        const key = try std.fmt.parseInt(i32, pair.next().?, 10);

        if (map.get(key)) |arraylist| {
            var list = arraylist;
            // print("key: {d} has alreay a value\n", .{key});
            try list.append(value);
            // for (list.items) |it| {
            //     print("{d} ", .{it});
            // }
            // print("\n", .{});
            try map.put(key, list);
        } else {
            var newarray = ArrayList(i32).init(allocator);
            try newarray.append(value);
            try map.put(key, newarray);
        }
    }
    return map;
}

fn partOne(allocator: Allocator, input: []const u8) !i32 {
    const lines = try splitLine(allocator, input);
    defer lines.deinit();

    var header: [][]const u8 = undefined;
    var footer: [][]const u8 = undefined;

    for (lines.items, 0..) |line, i| {
        if (line.len == 0) {
            header = lines.items[0..i];
            footer = lines.items[i + 1 .. lines.items.len - 1];
            break;
        }
    }

    var map = try getRules(allocator, header);
    defer map.deinit();

    const updates = try getUpdates(allocator, footer);
    defer updates.deinit();

    var total: i32 = 0;

    outer: for (updates.items) |list| {
        for (list.items, 0..) |num, i| {
            const rhs_slice = list.items[i..];
            if (map.get(num)) |arraylist| {
                for (arraylist.items) |item| {
                    for (rhs_slice) |rhs_num| {
                        if (item == rhs_num) {
                            continue :outer;
                        }
                    }
                }
            }
            // print("val: {d},{d}\n", .{ num, i });
        }
        // print("valid: ", .{});
        // for (list.items) |item| {
        //     print("{} ", .{item});
        // }
        // print("\n", .{});
        const middle = list.items.len / 2;
        total += list.items[middle];
    }

    for (updates.items) |list| {
        print("list: ", .{});
        for (list.items) |num| {
            print("{} ", .{num});
        }
        print("\n", .{});
    }

    var iterator = map.iterator();
    while (iterator.next()) |it| {
        print("[{d}]: ", .{it.key_ptr.*});
        for (it.value_ptr.items) |value| {
            print("{d} ", .{value});
        }
        print("\n", .{});
    }

    //clean up allocations
    for (updates.items) |list| list.deinit();
    var it = map.iterator();
    while (it.next()) |values| values.value_ptr.deinit();

    return total;
}

fn getIncorects(allocator: Allocator, updates: ArrayList(ArrayList(i32)), map: AutoHashMap(i32, ArrayList(i32))) !ArrayList(ArrayList(i32)) {
    var incorects = ArrayList(ArrayList(i32)).init(allocator);
    outer: for (updates.items) |list| {
        for (list.items, 0..) |num, i| {
            const rhs_slice = list.items[i..];
            if (map.get(num)) |arraylist| {
                for (arraylist.items) |item| {
                    for (rhs_slice) |rhs_num| {
                        if (item == rhs_num) {
                            try incorects.append(list);
                            continue :outer;
                        }
                    }
                }
            }
        }
    }
    return incorects;
}

fn fixList(list: ArrayList(i32), map: AutoHashMap(i32, ArrayList(i32))) !void {
    for (list.items, 0..) |num, i| {
        const rhs_slice = list.items[i..];
        if (map.get(num)) |arraylist| {
            for (arraylist.items) |item| {
                for (rhs_slice, 0..) |rhs_num, j| {
                    if (item == rhs_num) {
                        std.mem.swap(i32, &list.items[i], &list.items[i + j]);
                        try fixList(list, map);
                    }
                }
            }
        }
    }
}

fn partTwo(allocator: Allocator, input: []const u8) !i32 {
    const lines = try splitLine(allocator, input);
    defer lines.deinit();

    var header: [][]const u8 = undefined;
    var footer: [][]const u8 = undefined;

    for (lines.items, 0..) |line, i| {
        if (line.len == 0) {
            header = lines.items[0..i];
            footer = lines.items[i + 1 .. lines.items.len - 1];
            break;
        }
    }

    var map = try getRules(allocator, header);
    defer map.deinit();

    const updates = try getUpdates(allocator, footer);
    defer updates.deinit();

    var total: i32 = 0;

    var incorects = try getIncorects(allocator, updates, map);
    defer incorects.deinit();

    for (incorects.items) |list| {
        try fixList(list, map);
        const middle = list.items.len / 2;
        total += list.items[middle];
    }

    //clean up allocations
    for (updates.items) |list| list.deinit();
    var it = map.iterator();
    while (it.next()) |values| values.value_ptr.deinit();

    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day05/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day05/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    // const result_part_one_example = try partOne(gpa, p1_example_input);
    // print("Part one example result: {d}\n", .{result_part_one_example});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day05/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
