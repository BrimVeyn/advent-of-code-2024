const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const Vec2 = @Vector(2, i32);

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Context = struct {
    maze: ArrayList([]u8),
    deer: Vec2,
    end: Vec2,
    moves: usize = 0,
    turns: usize = 0,
    visited: AutoHashMap(Vec2, bool),

    pub fn clone(self: Context) !Context {
        return .{
            .maze = self.maze,
            .deer = self.deer,
            .end = self.end,
            .moves = self.moves,
            .turns = self.turns,
            .direction = self.direction,
            .visited = try self.visited.clone(),
        };
    }
};

fn parseInput(alloc: Allocator, input: []u8) !Context {
    var lines = mem.tokenizeScalar(u8, input, '\n');
    var startPos: Vec2 = undefined;
    var endPos: Vec2 = undefined;
    var y: i32 = 0;

    var maze = ArrayList([]u8).init(alloc);
    while (lines.next()) |line| : (y += 1) {
        if (mem.indexOf(u8, line, "E")) |x| {
            endPos = .{ @intCast(x), y };
        }
        if (mem.indexOf(u8, line, "S")) |x| {
            startPos = .{ @intCast(x), y };
        }
        try maze.append(try alloc.dupe(u8, line));
    }
    return .{
        .maze = maze,
        .deer = startPos,
        .end = endPos,
        .visited = AutoHashMap(Vec2, bool).init(alloc),
    };
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    var ctx = try parseInput(alloc, input);
    defer {
        for (ctx.maze.items) |line| alloc.free(line);
        ctx.visited.deinit();
        ctx.maze.deinit();
    }
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day16/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day16/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p1_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
