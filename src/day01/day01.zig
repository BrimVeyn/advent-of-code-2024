const p1_real = @embedFile("p1_input.txt");
const p1_ex = @embedFile("p1_example.txt");

const std = @import("std");
const print = std.debug.print;
const mem = std.mem;

pub fn main() !void {
    var splits = mem.splitScalar(u8, p1_ex, '\n');

    while (splits.next()) |it| {
        print("line: {s}\n", .{it});
    }
}
