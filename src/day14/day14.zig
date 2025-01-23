const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Robot = struct {
    pos: @Vector(2, i32),
    velocity: @Vector(2, i32),
};

fn parseLine(line: []const u8) !Robot {
    var eql_pos = std.mem.indexOf(u8, line, "=").?;
    var vir_pos = std.mem.indexOfPos(u8, line, eql_pos, ",").?;
    const space_pos = std.mem.indexOfPos(u8, line, vir_pos, " ").?;
    const posX = try std.fmt.parseInt(i32, line[eql_pos + 1 .. vir_pos], 10);
    const posY = try std.fmt.parseInt(i32, line[vir_pos + 1 .. space_pos], 10);

    eql_pos = std.mem.indexOfPos(u8, line, space_pos, "=").?;
    vir_pos = std.mem.indexOfPos(u8, line, eql_pos, ",").?;
    const vX = try std.fmt.parseInt(i32, line[eql_pos + 1 .. vir_pos], 10);
    const vY = try std.fmt.parseInt(i32, line[vir_pos + 1 ..], 10);

    return .{
        .pos = .{ posX, posY },
        .velocity = .{ vX, vY },
    };
}

fn partOne(allocator: Allocator, input: []u8) !usize {
    _ = allocator;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var quadrant: [4]usize = .{ 0, 0, 0, 0 };
    const dimX = 101;
    const dimY = 103;
    const halfX = dimX / 2;
    const halfY = dimY / 2;
    while (lines.next()) |line| {
        const robot = try parseLine(line);
        // robot = Robot{
        //     .pos = .{ 2, 4 },
        //     .velocity = .{ 2, -3 },
        // };
        // print("{any}\n", .{robot});
        const endX = @mod((robot.pos[0] + (100 * robot.velocity[0])), dimX);
        const endY = @mod((robot.pos[1] + (100 * robot.velocity[1])), dimY);
        if (endX < halfX and endY < halfY) quadrant[0] += 1;
        if (endX > halfX and endY < halfY) quadrant[1] += 1;
        if (endX < halfX and endY > halfY) quadrant[2] += 1;
        if (endX > halfX and endY > halfY) quadrant[3] += 1;
        // print("{d},{d}\n", .{ endX, endY });
    }
    print("Q: {any}\n", .{quadrant});
    return quadrant[0] * quadrant[1] * quadrant[2] * quadrant[3];
}

fn display(allocator: Allocator, robots: ArrayList(Robot), it: usize) !void {
    _ = allocator;
    var map: [103][101]u8 = .{.{'.'} ** 101} ** 103;

    for (robots.items) |robot| {
        const y: usize = @intCast(robot.pos[1]);
        const x: usize = @intCast(robot.pos[0]);
        map[y][x] = '1';
    }
    var buffer: [100]u8 = .{0} ** 100;
    const path = try std.fmt.bufPrint(&buffer, "tree{d}", .{it});

    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    for (map) |line| {
        _ = try file.write(&line);
        _ = try file.write("\n");
    }
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    var robots = ArrayList(Robot).init(allocator);
    defer robots.deinit();

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try robots.append(try parseLine(line));
    }

    const dimX = 101;
    const dimY = 103;
    const halfX = dimX / 2;
    const halfY = dimY / 2;

    for (0..100000) |i| {
        print("{d} secondes elapsed\n", .{i});
        var quadrant: [4]usize = .{ 0, 0, 0, 0 };
        for (robots.items) |*robot| {
            robot.pos[0] = @mod((robot.pos[0] + (100 * robot.velocity[0])), dimX);
            robot.pos[1] = @mod((robot.pos[1] + (100 * robot.velocity[1])), dimY);
            if (robot.pos[0] < halfX and robot.pos[1] < halfY) quadrant[0] += 1;
            if (robot.pos[0] > halfX and robot.pos[1] < halfY) quadrant[1] += 1;
            if (robot.pos[0] < halfX and robot.pos[1] > halfY) quadrant[2] += 1;
            if (robot.pos[0] > halfX and robot.pos[1] > halfY) quadrant[3] += 1;
        }
        if (quadrant[0] == quadrant[1] and quadrant[2] == quadrant[3]) {
            try display(allocator, robots, i);
        }
    }
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day14/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day14/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    // const result_part_one_example = try partOne(gpa, p1_example_input);
    // print("Part one example result: {d}\n", .{result_part_one_example});
    //
    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});
    //
    // const p2_input = try openAndRead("./src/day14/p1_input.txt", page_allocator);
    // defer page_allocator.free(p2_input); // Free the allocated memory after use
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    const result_part_two = try partTwo(gpa, p1_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
