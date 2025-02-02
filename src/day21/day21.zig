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
    alloc: Allocator,

    pub fn init(alloc: Allocator, input: []u8) !Context {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var i: usize = 0;
        var sequences: [5][]const u8 = undefined;
        while (it.next()) |line| : (i += 1) {
            sequences[i] = try alloc.dupe(u8, line);
        }

        return .{
            .sequences = sequences,
            .alloc = alloc,
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

    pub fn deinit(self: *Context) void {
        for (self.sequences) |code| self.alloc.free(code);
    }
};

const NumKeyPad = [_][]const u8{
    ".....",
    ".789.",
    ".456.",
    ".123.",
    "..0A.",
    ".....",
};

const DirKeyPad = [_][]const u8{
    ".....",
    "..^A.",
    ".<v>.",
    ".....",
};

const Dirs = [_]iVec2{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };

const State = struct {
    pos: iVec2,
    it: usize,
    path: ArrayList(iVec2),
};

fn bfsShortest(alloc: Allocator, sequence: []const u8, start: iVec2) !ArrayList([]iVec2) {
    var queue = ArrayList(State).init(alloc);
    defer queue.deinit();

    var paths = ArrayList([]iVec2).init(alloc);

    var visited = AutoHashMap(iVec2, ArrayList(usize)).init(alloc);
    defer {
        var vIt = visited.iterator();
        while (vIt.next()) |entry| {
            entry.value_ptr.deinit();
        }
        visited.deinit();
    }

    var basePath = ArrayList(iVec2).init(alloc);
    try basePath.append(start);
    try queue.append(State{ .path = basePath, .it = 0, .pos = start });

    while (queue.items.len > 0) {
        const state = queue.orderedRemove(0);
        var it = state.it;
        const pos = state.pos;
        var path = state.path;

        //Found a target, go next
        if (NumKeyPad[@intCast(pos[1])][@intCast(pos[0])] == sequence[it]) {
            it += 1;
        }

        //Found all targets
        if (it >= sequence.len) {
            print("Reached the end !\n", .{});
            const short_path = try path.toOwnedSlice();
            try paths.append(short_path);
            continue;
        }

        outer: for (Dirs) |dir| {
            const next: iVec2 = .{ pos[0] + dir[0], pos[1] + dir[1] };

            //Out of bounds
            if (NumKeyPad[@intCast(next[1])][@intCast(next[0])] == '.')
                continue;

            //Already visited with this target
            if (visited.get(next)) |list| {
                for (list.items) |prev_it| {
                    if (prev_it == it)
                        continue :outer;
                }
            }

            //Add visited
            const entry = try visited.getOrPutValue(next, ArrayList(usize).init(alloc));
            try entry.value_ptr.append(it);

            //Push new state
            var clone = try path.clone();
            try clone.append(next);
            try queue.append(State{ .pos = next, .it = it, .path = clone });
        }
        //Free current state path
        path.deinit();
    }

    return paths;
}

fn partOne(alloc: Allocator, input: []u8) !usize {
    var ctx = try Context.init(alloc, input);
    defer ctx.deinit();

    for (ctx.sequences) |sequence| {
        _ = sequence;
        // const A: iVec2 = .{ 3, 4 };
        const Tmp: iVec2 = .{ 2, 3 };
        const paths = try bfsShortest(alloc, "9", Tmp);
        defer {
            for (paths.items) |path| alloc.free(path);
            paths.deinit();
        }
        for (paths.items) |path| {
            print("{any}\n", .{path});
            for (path) |pos| {
                print("{c},", .{NumKeyPad[@intCast(pos[1])][@intCast(pos[0])]});
            }
            print("\n", .{});
        }
        break;
    }

    print("{}\n", .{ctx});
    // try rl_display(alloc, input);
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

    rl.initWindow(screenWidth, screenHeight, "Day21");
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
