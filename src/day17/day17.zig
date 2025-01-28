const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const ArrayListU = std.ArrayListUnmanaged;
const AutoHashMap = std.AutoHashMap;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const uVec2 = @Vector(2, usize);
const iVec2 = @Vector(2, i32);

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Context = struct {
    reg_A: usize,
    reg_B: usize,
    reg_C: usize,
    prog: ArrayList(usize),
    out: ArrayList(usize),
    pointer: usize = 0,
    jumped: bool = false,
};

fn parseInput(alloc: Allocator, input: []u8) !Context {
    var split = std.mem.tokenizeSequence(u8, input, "\n\n");
    const registers_str = split.next().?;

    var registers: [3]usize = .{ 0, 0, 0 };
    var regs = std.mem.tokenizeScalar(u8, registers_str, '\n');
    for (0..registers.len) |i| {
        const line = regs.next().?;
        const colon_pos = std.mem.indexOf(u8, line, ":").?;
        registers[i] = try std.fmt.parseInt(usize, line[colon_pos + 2 ..], 10);
    }

    var insts = ArrayList(usize).init(alloc);

    const inst_str = split.next().?;
    const inst_colon = std.mem.indexOf(u8, inst_str, ":").?;
    var inst_list = std.mem.tokenizeScalar(u8, inst_str[inst_colon + 2 .. inst_str.len - 1], ',');
    while (inst_list.next()) |inst| {
        try insts.append(try std.fmt.parseInt(usize, inst, 10));
    }

    return .{
        .prog = insts,
        .reg_A = registers[0],
        .reg_B = registers[1],
        .reg_C = registers[2],
        .out = ArrayList(usize).init(alloc),
    };
}

fn adv(ctx: *Context, combo_operand: usize) void {
    const raised_combo = std.math.pow(usize, 2, combo_operand);
    ctx.reg_A = @divTrunc(ctx.reg_A, raised_combo);
}

fn bxl(ctx: *Context, litteral_operand: usize) void {
    ctx.reg_B ^= litteral_operand;
}

fn bst(ctx: *Context, combo_operand: usize) void {
    ctx.reg_B = @mod(combo_operand, 8);
}

fn jnz(ctx: *Context, litteral_operand: usize) void {
    if (ctx.reg_A == 0) return;
    ctx.pointer = litteral_operand;
    ctx.jumped = true;
}

fn bxc(ctx: *Context) void {
    ctx.reg_C = (ctx.reg_B ^ ctx.reg_C);
}

fn out(ctx: *Context, combo_operand: usize) !void {
    const mod_combo = @mod(combo_operand, 8);
    try ctx.out.append(mod_combo);
}

fn bdv(ctx: *Context, combo_operand: usize) void {
    const raised_combo = std.math.pow(usize, 2, combo_operand);
    ctx.reg_B = @divTrunc(ctx.reg_A, raised_combo);
}

fn cdv(ctx: *Context, combo_operand: usize) void {
    const raised_combo = std.math.pow(usize, 2, combo_operand);
    ctx.reg_C = @divTrunc(ctx.reg_A, raised_combo);
}

fn execute_inst(ctx: *Context, opcode: usize, litteral_operand: usize, combo_operand: usize) !void {
    switch (opcode) {
        0 => adv(ctx, combo_operand),
        1 => bxl(ctx, litteral_operand),
        2 => bst(ctx, combo_operand),
        3 => jnz(ctx, litteral_operand),
        4 => bxc(ctx),
        5 => try out(ctx, combo_operand),
        6 => bdv(ctx, combo_operand),
        7 => cdv(ctx, combo_operand),
        else => {},
    }
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    var ctx = try parseInput(alloc, input);
    defer {
        ctx.prog.deinit();
        ctx.out.deinit();
    }

    while (ctx.pointer < ctx.prog.items.len) {
        const opcode = ctx.prog.items[ctx.pointer];
        const litteral_operand = ctx.prog.items[ctx.pointer + 1];
        const combo_operand = switch (litteral_operand) {
            0...3 => litteral_operand,
            4 => ctx.reg_A,
            5 => ctx.reg_B,
            6 => ctx.reg_C,
            7 => litteral_operand,
            else => @panic("Impossible"),
        };

        print("OPCODE: {d}, |{d},{d}| Pointer: {d}\n", .{ opcode, litteral_operand, combo_operand, ctx.pointer });
        try execute_inst(&ctx, opcode, litteral_operand, combo_operand);
        print("pointer: {d}\n", .{ctx.pointer});
        // print("ctx:\nA:{d}\nB:{d}\nC:{d}\nIns:{any}\n", .{ ctx.reg_A, ctx.reg_B, ctx.reg_C, ctx.prog.items });

        if (ctx.jumped) {
            ctx.jumped = !ctx.jumped;
            continue;
        } else {
            ctx.pointer += 2;
        }
    }
    print("ctx:\nA:{d}\nB:{d}\nC:{d}\nIns:{any}\n", .{ ctx.reg_A, ctx.reg_B, ctx.reg_C, ctx.prog.items });
    for (ctx.out.items) |item| {
        print("{d},", .{item});
    }
    print("\n", .{});

    // print("ctx:\nA:{d}\nB:{d}\nC:{d}\nIns:{any}\n", .{ ctx.reg_A, ctx.reg_B, ctx.reg_C, ctx.prog.items });
    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day17/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day17/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{res_ex});

    const res_real = try partOne(gpa, p1_input);
    print("Part one example result: {d}\n", .{res_real});

    // const result_part_one = try partOne(gpa, p1_input);
    // print("Part one result: {d}\n", .{result_part_one});
    //
    // const result_part_two_example = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{result_part_two_example});
    //
    // const result_part_two = try partTwo(gpa, p1_input);
    // print("Part two result: {d}\n", .{result_part_two});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
