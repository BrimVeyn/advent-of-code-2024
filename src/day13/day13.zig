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

const Coord = enum {
    X,
    Y,
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

fn modInverse(a: u128, mod: u128) u128 {
    for (0..1000) |i| {
        if (@mod(a * i, mod) == 1)
            return i;
    }
    return 0;
}

fn trySolve(ctx: Context, const_A: i128, const_B: i128, kA: i128, kB: i128) i128 {
    const bAx128: i128 = @intCast(ctx.buttonA.x);
    const bAy128: i128 = @intCast(ctx.buttonA.y);
    const bBx128: i128 = @intCast(ctx.buttonB.x);
    const bBy128: i128 = @intCast(ctx.buttonB.y);
    for (1..2) |k| {
        const nA = (kA * k) + const_A;
        const nB = const_B - (kB * k);
        const resX = nA * bAx128 + nB * bBx128;
        const resY = nA * bAy128 + nB * bBy128;
        _ = resX;
        // print("resX: {d} | resY: {d}\n", .{ resX, resY });

        const prizeYi128: i128 = @intCast(ctx.prize.y);
        // print("{d}\n", .{resY});
        const variation = (kA * bAy128) - (kB * bBy128);
        const platPrizeY = (resY) - prizeYi128;
        // print("var: {d}\n", .{variation});
        // print("goal: {d}\n", .{platPrizeY});
        // print("{d}\n", .{prizeYi128 - (const_B * bBy128)});
        // print("MOD: {d}\n", .{@mod(platPrizeY, variation)});
        if (@mod(platPrizeY, variation) == 0) {
            // print("solution !\n", .{});
            const kY = @divExact(platPrizeY, variation);
            print("DIST to solution: {d}\n", .{kY});
            const _nA = const_A + (kA * -(kY - 1));
            const _nB = const_B - (kB * -(kY - 1));
            print("Solution: [{d}][{d}]\n", .{ const_A + (kA * -(kY - 1)), const_B - (kB * -(kY - 1)) });
            return _nA * 3 + _nB;
            // const _nA = (kA * kY) + const_A;
            // const _nB = const_B - (kB * kY);
            // const _resX = _nA * bAx128 + _nB * bBx128;
            // const _resY = _nA * bAy128 + _nB * bBy128;
            // print("REAL resX: {d} | resY: {d}\n", .{ _resX, _resY });
            // print("target: {d}\n", .{resY * -kY});
        }
        // print("resX: {d}\n", .{constant_a * @as(u128, @intCast(ctx.buttonA.x)) + constant_b * @as(u128, @intCast(ctx.buttonB.x))});
    }
    return 0;
}

fn solveDiophantienne(
    ctx: Context,
    coord: Coord,
) !struct { u128, u128, u128, u128 } {
    const bAcoo = if (coord == Coord.X) ctx.buttonA.x else ctx.buttonA.y;
    const bBcoo = if (coord == Coord.X) ctx.buttonB.x else ctx.buttonB.y;
    const prizeCoo = if (coord == Coord.X) ctx.prize.x else ctx.prize.y;

    const modulo = bBcoo;
    const prizeXrem = @rem(prizeCoo, modulo);
    const aXrem = @rem(bAcoo, modulo);
    // print("{d} - {d}a = 0 [{d}]\n", .{ prizeXrem, aXrem, modulo });

    const gcdaXprizeX = std.math.gcd(@as(u64, @intCast(aXrem)), @as(u64, @intCast(modulo)));
    const simpPrizeX = @divExact(@as(u128, @intCast(prizeXrem)), @as(u128, @intCast(gcdaXprizeX)));
    const simpaX = @divExact(@as(u128, @intCast(aXrem)), @as(u128, @intCast(gcdaXprizeX)));
    const kA = @divExact(@as(u128, @intCast(modulo)), @as(u128, @intCast(gcdaXprizeX)));
    // print("{d}nA = {d} [{d}]\n", .{ simpaX, simpPrizeX, simpModulo });

    const simpAinverse = modInverse(simpaX, kA);
    // print("nA = {d} * {d} [{d}]\n", .{ simpPrizeX, simpAinverse, simpModulo });

    // const char: u8 = if (coord == Coord.X) 'X' else 'Y';
    const constant_a = @mod(simpPrizeX * simpAinverse, kA);
    // print("nA{c} = {d} + {d}k\n", .{ char, constant_a, kA });

    const kB = @as(u128, @intCast(bAcoo)) * kA / @as(u128, @intCast(bBcoo));
    const constant_b = (@as(u128, @intCast(prizeCoo)) - (@as(u128, @intCast(bAcoo)) * constant_a)) / @as(u128, @intCast(bBcoo));
    // print("nB{c} = {d} - {d}k\n", .{ char, constant_b, kB });

    return .{
        constant_a,
        kA,
        constant_b,
        kB,
    };
}

fn isSolvable(ctx: Context, total: *i128) !bool {
    const gcdX = std.math.gcd(@as(u64, @intCast(ctx.buttonA.x)), @as(u64, @intCast(ctx.buttonB.x)));
    const gcdY = std.math.gcd(@as(u64, @intCast(ctx.buttonA.y)), @as(u64, @intCast(ctx.buttonB.y)));

    if (@mod(ctx.prize.x, @as(i64, @intCast(gcdX))) != 0 or @mod(ctx.prize.y, @as(i64, @intCast(gcdY))) != 0) {
        print("gcdX: {d}, gcdY: {d}\n", .{ gcdX, gcdY });
        return false;
    }

    // const cAx, const nAx, const cBx, const nBx = try solveDiophantienne(ctx, Coord.X);
    // const cAy, const nAy, const cBy, const nBy = try solveDiophantienne(ctx, Coord.Y);
    _ = try solveDiophantienne(ctx, Coord.Y);
    _ = try solveDiophantienne(ctx, Coord.X);

    const modulo = ctx.buttonB.x;
    const prizeXrem = @rem(ctx.prize.x, modulo);
    const aXrem = @rem(ctx.buttonA.x, modulo);
    // print("{d} - {d}a = 0 [{d}]\n", .{ prizeXrem, aXrem, modulo });

    const gcdaXprizeX = std.math.gcd(@as(u64, @intCast(aXrem)), @as(u64, @intCast(modulo)));
    const simpPrizeX = @divExact(@as(u128, @intCast(prizeXrem)), @as(u128, @intCast(gcdaXprizeX)));
    const simpaX = @divExact(@as(u128, @intCast(aXrem)), @as(u128, @intCast(gcdaXprizeX)));
    const simpModulo = @divExact(@as(u128, @intCast(modulo)), @as(u128, @intCast(gcdaXprizeX)));
    // print("{d}nA = {d} [{d}]\n", .{ simpaX, simpPrizeX, simpModulo });

    const simpAinverse = modInverse(simpaX, simpModulo);
    // print("nA = {d} * {d} [{d}]\n", .{ simpPrizeX, simpAinverse, simpModulo });

    const constant_a = @mod(simpPrizeX * simpAinverse, simpModulo);
    print("nA = {d} + {d}k\n", .{ constant_a, simpModulo });

    const kB = @as(u128, @intCast(ctx.buttonA.x)) * simpModulo / @as(u128, @intCast(ctx.buttonB.x));
    const constant_b = (@as(u128, @intCast(ctx.prize.x)) - (@as(u128, @intCast(ctx.buttonA.x)) * constant_a)) / @as(u128, @intCast(ctx.buttonB.x));
    print("nB = {d} - {d}k\n", .{ constant_b, kB });

    total.* += trySolve(ctx, @as(i128, @intCast(constant_a)), @as(i128, @intCast(constant_b)), @as(i128, @intCast(simpModulo)), @as(i128, @intCast(kB)));

    return true;
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
        var subtotal: i128 = 0;
        const solvable = try isSolvable(ctx, &subtotal);
        if (solvable) {
            print("A: {d},{d} B: {d},{d} P: {d},{d}\n", .{ ctx.buttonA.x, ctx.buttonA.y, ctx.buttonB.x, ctx.buttonB.y, ctx.prize.x, ctx.prize.y });
            total_tokens += try dfs(allocator, &ctx);
        }
    }
    return total_tokens;
}

fn partTwo(allocator: Allocator, input: []u8) !i128 {
    var it = std.mem.tokenizeSequence(u8, input, "\n\n");
    var total_tokens: usize = 0;
    var subtotal: i128 = 0;
    while (it.next()) |machine| {
        // print("{s}\n", .{machine});
        var ctx = try parseMachine(machine, Part.TWO);
        // print("A: {d},{d} B: {d},{d} P: {d},{d}\n", .{ ctx.buttonA.x, ctx.buttonA.y, ctx.buttonB.x, ctx.buttonB.y, ctx.prize.x, ctx.prize.y });
        const solvable = try isSolvable(ctx, &subtotal);
        if (solvable) {
            total_tokens += try dfs(allocator, &ctx);
        }
    }
    return subtotal;
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

    const result_part_two = try partTwo(gpa, p1_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
