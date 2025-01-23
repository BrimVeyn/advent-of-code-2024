const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

const rl = @import("raylib");

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

const Dim = enum(i32) {
    X = 101,
    Y = 103,
};

const Scale = 8;

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

    const halfX = @intFromEnum(Dim.X) / 2;
    const halfY = @intFromEnum(Dim.Y) / 2;

    while (lines.next()) |line| {
        const robot = try parseLine(line);
        const endX = @mod((robot.pos[0] + (100 * robot.velocity[0])), @intFromEnum(Dim.X));
        const endY = @mod((robot.pos[1] + (100 * robot.velocity[1])), @intFromEnum(Dim.Y));
        if (endX < halfX and endY < halfY) quadrant[0] += 1;
        if (endX > halfX and endY < halfY) quadrant[1] += 1;
        if (endX < halfX and endY > halfY) quadrant[2] += 1;
        if (endX > halfX and endY > halfY) quadrant[3] += 1;
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

fn partTwo(robots: *ArrayList(Robot), start: *usize) !void {
    const halfX = @intFromEnum(Dim.X) / 2;
    const halfY = @intFromEnum(Dim.Y) / 2;

    for (0..100000000) |i| {
        print("{d} secondes elapsed\n", .{start.* + i});
        var quadrant: [4]usize = .{ 0, 0, 0, 0 };
        for (robots.items) |*robot| {
            robot.pos[0] = @mod((robot.pos[0] + robot.velocity[0]), @intFromEnum(Dim.X));
            robot.pos[1] = @mod((robot.pos[1] + robot.velocity[1]), @intFromEnum(Dim.Y));
            if (robot.pos[0] < halfX and robot.pos[1] < halfY) quadrant[0] += 1;
            if (robot.pos[0] > halfX and robot.pos[1] < halfY) quadrant[1] += 1;
            if (robot.pos[0] < halfX and robot.pos[1] > halfY) quadrant[2] += 1;
            if (robot.pos[0] > halfX and robot.pos[1] > halfY) quadrant[3] += 1;
        }
        start.* += 1;
        if (quadrant[0] > quadrant[1] and quadrant[0] > quadrant[2] and quadrant[0] > quadrant[3]) {
            return;
        }
    }
    return;
}

fn rl_display(allocator: Allocator, input: []u8) !void {
    const screenWidth = @intFromEnum(Dim.X) * Scale;
    const screenHeight = @intFromEnum(Dim.Y) * Scale;
    print("{d} by {d}\n", .{ screenWidth, screenHeight });

    var robots = ArrayList(Robot).init(allocator);
    defer robots.deinit();

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try robots.append(try parseLine(line));
    }

    const start: usize = 7412;
    const starti32: i32 = @intCast(start);
    for (robots.items) |*robot| {
        robot.pos[0] = @mod((robot.pos[0] + (robot.velocity[0] * starti32)), @intFromEnum(Dim.X));
        robot.pos[1] = @mod((robot.pos[1] + (robot.velocity[1] * starti32)), @intFromEnum(Dim.Y));
    }

    var map: [103][101]u8 = .{.{'.'} ** 101} ** 103;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(40); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        if (rl.isKeyPressed(.l)) {
            for (robots.items) |*robot| {
                robot.pos[0] = @mod((robot.pos[0] + robot.velocity[0]), @intFromEnum(Dim.X));
                robot.pos[1] = @mod((robot.pos[1] + robot.velocity[1]), @intFromEnum(Dim.Y));
            }
        }
        if (rl.isKeyPressed(.h)) {
            for (robots.items) |*robot| {
                robot.pos[0] = @mod((robot.pos[0] - robot.velocity[0]), @intFromEnum(Dim.X));
                robot.pos[1] = @mod((robot.pos[1] - robot.velocity[1]), @intFromEnum(Dim.Y));
            }
        }

        for (robots.items) |robot| {
            const y: usize = @intCast(robot.pos[1]);
            const x: usize = @intCast(robot.pos[0]);
            map[y][x] = '1';
        }

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        for (map, 0..) |line, i| {
            for (line, 0..) |ch, j| {
                // void DrawRectangle(int posX, int posY, int width, int height, Color color);
                const color = if (ch == '1') rl.Color.lime else rl.Color.black;
                // _ = ch;
                // _ = i;
                // _ = j;
                const posX: i32 = @intCast(j * Scale);
                const posY: i32 = @intCast(i * Scale);
                // print("{d},{d}\n", .{ posY, posX });
                rl.drawRectangle(posX, posY, Scale, Scale, color);
            }
        }

        map = .{.{'.'} ** 101} ** 103;

        //----------------------------------------------------------------------------------
    }
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const gpa = general_purpose_allocator.allocator();

    const p1_input = try openAndRead("./src/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    // const result_part_two = try partTwo(gpa, p1_input);
    // print("Part two result: {d}\n", .{result_part_two});

    try rl_display(gpa, p1_input);

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}

