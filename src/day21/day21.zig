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

const rl = @import("raylib");

fn openAndRead(path: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 1_000_000);
    return file_content;
}

const Context = struct {
    sequences: [5][]const u8 = undefined,

    pub fn init(alloc: Allocator, input: []u8) !Context {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var i: usize = 0;
        var sequences: [5][]const u8 = undefined;
        while (it.next()) |line| : (i += 1) {
            sequences[i] = try alloc.dupe(u8, line);
        }

        return .{
            .sequences = sequences,
        };
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginArray();
        for (self.sequences) |seq| {
            try jws.print("|{s}|", .{seq});
        }
        try jws.endArray();
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try std.json.stringify(self, .{ .whitespace = .indent_2 }, writer);
    }
};

const NumKeyPad = .{
    "789",
    "456",
    "123",
    "X0A",
};

const DirKeyPad = .{
    "X^A",
    "<v>",
};

fn partOne(alloc: Allocator, input: []u8) !usize {
    const ctx = try Context.init(alloc, input);
    defer {
        for (ctx.sequences) |code| alloc.free(code);
    }

    print("{}\n", .{ctx});
    try rl_display(alloc, input);
    return 0;
}

const ScreenW: usize = 1000;
const ScreenH: usize = 1000;
const centerX: usize = ScreenW / 2;
const centerY: usize = ScreenH / 2;

fn rl_display(alloc: Allocator, input: []u8) !void {
    _ = alloc;
    _ = input;
    const screenWidth = ScreenW;
    const screenHeight = ScreenH;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // if (rl.isKeyPressed(.l)) {
        //     for (robots.items) |*robot| {
        //         robot.pos[0] = @mod((robot.pos[0] + robot.velocity[0]), @intFromEnum(Dim.X));
        //         robot.pos[1] = @mod((robot.pos[1] + robot.velocity[1]), @intFromEnum(Dim.Y));
        //     }
        // }
        // try partTwo(&robots, &start);

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.yellow);

        //----------------------------------------------------------------------------------
    }
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day21/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day21/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{res_ex});

    // const res_real = try partOne(gpa, p1_input);
    // print("Part one example result: {d}\n", .{res_real});

    // const res_ex2 = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{res_ex2});
    //
    // const res_real2 = try partTwo(gpa, p1_input);
    // print("Part two example result: {d}\n", .{res_real2});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
