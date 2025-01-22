const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
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
    while (lines.next()) |line| {
        const robot = try parseLine(line);
        // robot = Robot{
        //     .pos = .{ 2, 4 },
        //     .velocity = .{ 2, -3 },
        // };
        print("{any}\n", .{robot});
        const endX = @mod((robot.pos[0] + (100 * robot.velocity[0])), 11);
        const endY = @mod((robot.pos[1] + (100 * robot.velocity[1])), 7);
        print("{d},{d}\n", .{ endX, endY });
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

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});
    //
    // const p2_input = try openAndRead("./src/day14/p1_input.txt", page_allocator);
    // defer page_allocator.free(p2_input); // Free the allocated memory after use
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
