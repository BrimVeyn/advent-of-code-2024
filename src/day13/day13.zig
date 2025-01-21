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

const CostA = 3;
const CostB = 1;

const Point = struct {
    x: i64,
    y: i64,

    pub const default: Point = .{
        .x = 0,
        .y = 0,
    };
};

const Context = struct {
    claw: Point = .default,
    buttonA: Point,
    buttonB: Point,
    prize: Point,
    countA: usize = 0,
    countB: usize = 0,
};

fn parseButton(line: []const u8) !Point {
    const posX = std.mem.indexOfPos(u8, line, 0, "X").?;
    const posvir = std.mem.indexOfPos(u8, line, 0, ",").?;
    const posY = std.mem.indexOfPos(u8, line, 0, "Y").?;
    const buttonX = try std.fmt.parseInt(i64, line[posX + 1 .. posvir], 10);
    const buttonY = try std.fmt.parseInt(i64, line[posY + 1 ..], 10);
    return .{ .x = buttonX, .y = buttonY };
}

fn parsePrize(line: []const u8) !Point {
    const fequal = std.mem.indexOfPos(u8, line, 0, "=").?;
    const vir = std.mem.indexOfPos(u8, line, 0, ",").?;
    const prizeX = try std.fmt.parseInt(i64, line[fequal + 1 .. vir], 10);
    const sequal = std.mem.indexOfPos(u8, line, fequal + 1, "=").?;
    const prizeY = try std.fmt.parseInt(i64, line[sequal + 1 ..], 10);
    return .{ .x = prizeX, .y = prizeY };
}

fn parseMachine(machine: []const u8) !Context {
    var lines = std.mem.tokenizeScalar(u8, machine, '\n');
    const lineA = lines.next().?;
    const lineB = lines.next().?;
    const linePrize = lines.next().?;

    const buttonA = try parseButton(lineA);
    const buttonB = try parseButton(lineB);
    const prize = try parsePrize(linePrize);
    return .{
        .buttonA = buttonA,
        .buttonB = buttonB,
        .prize = prize,
    };
}

fn isSolvable(ctx: Context) !bool {
    const gcdX = std.math.gcd(@as(u64, @intCast(ctx.buttonA.x)), @as(u64, @intCast(ctx.buttonB.x)));
    const gcdY = std.math.gcd(@as(u64, @intCast(ctx.buttonA.y)), @as(u64, @intCast(ctx.buttonB.y)));
    const floatSolutionX: f32 = @as(f32, @floatFromInt(ctx.prize.x)) / @as(f32, @floatFromInt(gcdX));
    const floatSolutionY: f32 = @as(f32, @floatFromInt(ctx.prize.y)) / @as(f32, @floatFromInt(gcdY));
    const intSolutionX: f32 = @as(f32, @floatFromInt(@as(u64, @intFromFloat(floatSolutionX))));
    const intSolutionY: f32 = @as(f32, @floatFromInt(@as(u64, @intFromFloat(floatSolutionY))));
    if (intSolutionX != floatSolutionX or intSolutionY != floatSolutionY) {
        return false;
    }
    return true;
}

fn dfs(allocator: Allocator, ctx: *Context) !usize {
    var solutions = ArrayList(struct { usize, usize }).init(allocator);
    defer solutions.deinit();

    for (0..100) |nA| {
        var map = AutoHashMap(i64, bool).init(allocator);
        defer map.deinit();

        for (1..100) |nB| {
            ctx.claw.x = (ctx.buttonA.x * @as(i64, @intCast(nA))) + (ctx.buttonB.x * @as(i64, @intCast(nB)));
            ctx.claw.y = (ctx.buttonA.y * @as(i64, @intCast(nA))) + (ctx.buttonB.y * @as(i64, @intCast(nB)));
            const modNb = @mod(ctx.claw.x, ctx.prize.x);

            if (modNb == 0 and ctx.claw.y == ctx.prize.y) {
                try solutions.append(.{ nA, nB });
                break;
            }

            if (map.get(modNb) != null) {
                break;
            }

            try map.put(modNb, true);
        }
    }
    // print("solutions: {any}\n", .{solutions.items});

    var min_cost: usize = if (solutions.items.len != 0) solutions.items[0][0] * 3 + solutions.items[0][1] else 0;
    for (solutions.items) |item| {
        const cost = item[0] * 3 + item[1];
        min_cost = @min(min_cost, cost);
    }

    // print("min_cost: {d}\n", .{min_cost});

    return min_cost;
}

fn partOne(allocator: Allocator, input: []u8) !usize {
    var it = std.mem.tokenizeSequence(u8, input, "\n\n");
    var total_tokens: usize = 0;
    while (it.next()) |machine| {
        // print("{s}\n", .{machine});
        var ctx = try parseMachine(machine);
        // print("A: {d},{d} B: {d},{d P: {d},{d}\n", .{ ctx.buttonA.x, ctx.buttonA.y, ctx.buttonB.x, ctx.buttonB.y, ctx.prize.x, ctx.prize.y });
        const solvable = try isSolvable(ctx);
        if (solvable) {
            total_tokens += try dfs(allocator, &ctx);
        }
    }
    return total_tokens;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day13/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day13/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});
    //
    // const p2_input = try openAndRead("./src/day12/p1_input.txt", page_allocator);
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
