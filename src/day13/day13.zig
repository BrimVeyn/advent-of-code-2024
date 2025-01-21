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

const Part = enum {
    ONE,
    TWO,
};

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

fn parsePrize(line: []const u8, p: Part) !Point {
    const fequal = std.mem.indexOfPos(u8, line, 0, "=").?;
    const vir = std.mem.indexOfPos(u8, line, 0, ",").?;
    var prizeX = try std.fmt.parseInt(i64, line[fequal + 1 .. vir], 10);
    const sequal = std.mem.indexOfPos(u8, line, fequal + 1, "=").?;
    var prizeY = try std.fmt.parseInt(i64, line[sequal + 1 ..], 10);
    if (p == Part.TWO) {
        prizeX += 10000000000000;
        prizeY += 10000000000000;
    }
    return .{ .x = prizeX, .y = prizeY };
}

fn parseMachine(machine: []const u8, p: Part) !Context {
    var lines = std.mem.tokenizeScalar(u8, machine, '\n');
    const lineA = lines.next().?;
    const lineB = lines.next().?;
    const linePrize = lines.next().?;

    const buttonA = try parseButton(lineA);
    const buttonB = try parseButton(lineB);
    const prize = try parsePrize(linePrize, p);
    return .{
        .buttonA = buttonA,
        .buttonB = buttonB,
        .prize = prize,
    };
}

fn isSolvable(ctx: Context) !bool {
    const gcdX = std.math.gcd(@as(u64, @intCast(ctx.buttonA.x)), @as(u64, @intCast(ctx.buttonB.x)));
    const gcdY = std.math.gcd(@as(u64, @intCast(ctx.buttonA.y)), @as(u64, @intCast(ctx.buttonB.y)));

    if (@mod(ctx.prize.x, @as(i64, @intCast(gcdX))) == 0 and @mod(ctx.prize.y, @as(i64, @intCast(gcdY))) == 0) {
        print("gcdX: {d}, gcdY: {d}\n", .{ gcdX, gcdY });
        return true;
    }
    return false;
}

fn dfs(allocator: Allocator, ctx: *Context) !usize {
    var solutions = ArrayList(struct { usize, usize }).init(allocator);
    defer solutions.deinit();

    for (0..100) |nA| {
        const first = (ctx.buttonA.x * @as(i64, @intCast(nA))) + (ctx.buttonB.x);
        const diff = ctx.prize.x - first;
        if (@mod(diff, ctx.buttonB.x) == 0) {
            const acutal_nb = @divExact(diff, ctx.buttonB.x) + 1;
            if (acutal_nb <= 0 or acutal_nb > 100) continue;

            ctx.claw.y = (ctx.buttonA.y * @as(i64, @intCast(nA))) + (ctx.buttonB.y * @as(i64, @intCast(acutal_nb)));
            if (ctx.claw.y != ctx.prize.y) continue;

            try solutions.append(.{ nA, @as(usize, @intCast(acutal_nb)) });
        }
    }
    print("solutions: {any}\n", .{solutions.items});

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
        var ctx = try parseMachine(machine, Part.ONE);
        const solvable = try isSolvable(ctx);
        if (solvable) {
            print("A: {d},{d} B: {d},{d} P: {d},{d}\n", .{ ctx.buttonA.x, ctx.buttonA.y, ctx.buttonB.x, ctx.buttonB.y, ctx.prize.x, ctx.prize.y });
            total_tokens += try dfs(allocator, &ctx);
        }
    }
    return total_tokens;
}

fn partTwo(allocator: Allocator, input: []u8) !usize {
    var it = std.mem.tokenizeSequence(u8, input, "\n\n");
    var total_tokens: usize = 0;
    while (it.next()) |machine| {
        // print("{s}\n", .{machine});
        var ctx = try parseMachine(machine, Part.TWO);
        const solvable = try isSolvable(ctx);
        if (solvable) {
            print("A: {d},{d} B: {d},{d} P: {d},{d}\n", .{ ctx.buttonA.x, ctx.buttonA.y, ctx.buttonB.x, ctx.buttonB.y, ctx.prize.x, ctx.prize.y });
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

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});

    // const p2_input = try openAndRead("./src/day12/p1_input.txt", page_allocator);
    // defer page_allocator.free(p2_input); // Free the allocated memory after use
    //
    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p2_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
