const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

fn openAndRead(allocator: Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Equation = struct {
    solution: u64,
    numbers: ArrayList(u64),
};

fn parseInput(allocator: Allocator, input: []u8) !ArrayList(Equation) {
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var equations = ArrayList(Equation).init(allocator);
    while (lines.next()) |line| {
        var pair = std.mem.tokenizeScalar(u8, line, ':');
        const lhs = try std.fmt.parseInt(u64, pair.next().?, 10);
        var rhs = std.mem.tokenizeScalar(u8, pair.next().?, ' ');
        var nums = ArrayList(u64).init(allocator);
        while (rhs.next()) |num| try nums.append(try std.fmt.parseInt(u64, num, 10));
        try equations.append(.{ .solution = lhs, .numbers = nums });
    }
    return equations;
}

const Context = struct {
    step: usize,
    partial_result: u64,
};

fn dfsPartOne(equation: Equation, ctx: Context) bool {
    if (ctx.step == equation.numbers.items.len) {
        if (ctx.partial_result == equation.solution)
            return true;
        return false;
    }

    const lhs = dfsPartOne(equation, .{
        .partial_result = (ctx.partial_result + equation.numbers.items[ctx.step]),
        .step = ctx.step + 1,
    });

    const rhs = dfsPartOne(equation, .{
        .partial_result = (ctx.partial_result * equation.numbers.items[ctx.step]),
        .step = ctx.step + 1,
    });

    return (lhs or rhs);
}

fn partOne(allocator: Allocator, input: []u8) !u64 {
    var equations = try parseInput(allocator, input);
    defer {
        for (equations.items) |equation| equation.numbers.deinit();
        equations.deinit();
    }
    var total: usize = 0;
    for (equations.items) |equation| {
        const solvable = dfsPartOne(equation, .{ .partial_result = equation.numbers.items[0], .step = 1 });
        total += if (solvable) equation.solution else 0;
    }
    return total;
}

fn concat(a: u64, b: u64) !u64 {
    // print("concat: {} {}\n", .{ a, b });
    var buffer: [50]u8 = .{0} ** 50;
    const res_str = try std.fmt.bufPrint(&buffer, "{d}{d}", .{ a, b });
    return try std.fmt.parseInt(u64, res_str, 10);
}

fn dfsPartTwo(equation: Equation, ctx: Context) !bool {
    if (ctx.step == equation.numbers.items.len) {
        if (ctx.partial_result == equation.solution)
            return true;
        return false;
    }

    const branch_one = try dfsPartTwo(equation, .{
        .partial_result = (ctx.partial_result + equation.numbers.items[ctx.step]),
        .step = ctx.step + 1,
    });

    const branch_two = try dfsPartTwo(equation, .{
        .partial_result = (ctx.partial_result * equation.numbers.items[ctx.step]),
        .step = ctx.step + 1,
    });

    const branch_three = try dfsPartTwo(equation, .{
        .partial_result = try concat(ctx.partial_result, equation.numbers.items[ctx.step]),
        .step = ctx.step + 1,
    });

    return (branch_one or branch_two or branch_three);
}

fn partTwo(allocator: Allocator, input: []u8) !u64 {
    var equations = try parseInput(allocator, input);
    defer {
        for (equations.items) |equation| equation.numbers.deinit();
        equations.deinit();
    }
    var total: usize = 0;
    for (equations.items) |equation| {
        const solvable = try dfsPartTwo(equation, .{ .partial_result = equation.numbers.items[0], .step = 1 });
        total += if (solvable) equation.solution else 0;
    }
    return total;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead(page_allocator, "./src/day07/p1_example.txt");
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead(page_allocator, "./src/day07/p1_input.txt");
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const result_part_one_example = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{result_part_one_example});

    const result_part_one = try partOne(gpa, p1_input);
    print("Part one result: {d}\n", .{result_part_one});

    const p2_input = try openAndRead(page_allocator, "./src/day07/p2_input.txt");
    defer page_allocator.free(p2_input); // Free the allocated memory after use

    const result_part_two_example = try partTwo(gpa, p1_example_input);
    print("Part two example result: {d}\n", .{result_part_two_example});

    const result_part_two = try partTwo(gpa, p2_input);
    print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
