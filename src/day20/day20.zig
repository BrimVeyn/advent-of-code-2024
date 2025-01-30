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

const WALL: usize = 99999999999999999;

const Cheat = struct {
    pos: uVec2,
    saved: usize,
};

const Context = struct {
    raceTrack: [][]u8,
    tracks: [][]usize,
    cheats: ArrayList(Cheat),
    end: uVec2,

    pub fn init(alloc: Allocator, input: []u8) !Context {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var raceTrackVec = ArrayList([]u8).init(alloc);

        var y: usize = 0;
        var end: uVec2 = undefined;

        while (it.next()) |line| : (y += 1) {
            try raceTrackVec.append(try alloc.dupe(u8, line));
            const idx = std.mem.indexOfScalar(u8, line, 'E');
            if (idx) |x| {
                end = .{ x, y };
            }
        }

        const raceTrack = try raceTrackVec.toOwnedSlice();
        var tracks = try ArrayList([]usize).initCapacity(alloc, y);
        for (0..y) |_| {
            var default = try ArrayList(usize).initCapacity(alloc, y);
            default.appendNTimesAssumeCapacity(WALL, y);
            tracks.appendAssumeCapacity(try default.toOwnedSlice());
        }

        return .{
            .raceTrack = raceTrack,
            .tracks = try tracks.toOwnedSlice(),
            .cheats = ArrayList(Cheat).init(alloc),
            .end = end,
        };
    }

    pub fn fillTracks(self: *Context, alloc: Allocator) !void {
        var visited = AutoHashMap(uVec2, bool).init(alloc);
        defer visited.deinit();

        var dist: usize = 1;
        var car = self.end;
        while (true) {
            defer dist += 1;
            if (self.raceTrack[car[1]][car[0]] == 'S')
                break;
            if (car[0] > 0) {
                const up: uVec2 = .{ car[0 - 1], car[1] };
                if (self.raceTrack[up[1]][up[0]] == '.' and visited.get(up) == null) {
                    self.tracks[up[1]][up[0]] = dist;
                }
            }
            if (car[0] < self.raceTrack.len) {
                const down: uVec2 = .{ car[0 + 1], car[1] };
                if (self.raceTrack[down[1]][down[0]] == '.' and visited.get(down) == null) {
                    self.tracks[down[1]][down[0]] = dist;
                }
            }
            if (car[1] > 0) {
                const up: uVec2 = .{ car[0 - 1], car[1] };
                if (self.raceTrack[up[1]][up[0]] == '.' and visited.get(up) == null) {
                    self.tracks[up[1]][up[0]] = dist;
                }
            }
            if (car[0] < self.raceTrack.len) {
                const down: uVec2 = .{ car[0 + 1], car[1] };
                if (self.raceTrack[down[1]][down[0]] == '.' and visited.get(down) == null) {
                    self.tracks[down[1]][down[0]] = dist;
                }
            }
        }
    }
};

fn partOne(alloc: Allocator, input: []u8) !usize {
    const ctx = try Context.parseInput(alloc, input);
    defer {
        for (ctx.raceTrack) |line| alloc.free(line);
        alloc.free(ctx.raceTrack);
        for (ctx.tracks) |line| alloc.free(line);
        alloc.free(ctx.tracks);
    }

    return 0;
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    const p1_example_input = try openAndRead("./src/day19/p1_example.txt", page_allocator);
    defer page_allocator.free(p1_example_input); // Free the allocated memory after use

    const p1_input = try openAndRead("./src/day19/p1_input.txt", page_allocator);
    defer page_allocator.free(p1_input); // Free the allocated memory after use

    const res_ex = try partOne(gpa, p1_example_input);
    print("Part one example result: {d}\n", .{res_ex});

    // const res_real = try partOne(gpa, p1_input);
    // print("Part one example result: {d}\n", .{res_real});
    //
    // const res_ex2 = try partTwo(gpa, p1_example_input);
    // print("Part two example result: {d}\n", .{res_ex2});
    //
    // const res_real2 = try partTwo(gpa, p1_input);
    // print("Part two example result: {d}\n", .{res_real2});

    const leaks = general_purpose_allocator.deinit();
    _ = leaks;
}
