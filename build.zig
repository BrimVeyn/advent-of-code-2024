const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external

const Days = [_][]const u8{
    "day01",
    "day02",
    "day03",
    "day04",
    "day05",
    "day06",
    "day07",
    "day08",
    "day09",
    "day10",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const check_step = b.step("check", "Checks");
    for (Days) |day| {
        var buffer: [128]u8 = .{0} ** 128;
        const root_file = try std.fmt.bufPrint(&buffer, "src/{s}/{s}.zig", .{ day, day });
        const module = b.createModule(.{
            .root_source_file = b.path(root_file),
            .target = target,
            .optimize = optimize,
        });
        const exe = b.addExecutable(.{
            .name = day,
            .root_module = module,
        });
        b.installArtifact(exe);
        const exec_check = b.addExecutable(.{
            .name = day,
            .root_module = module,
        });
        check_step.dependOn(&exec_check.step);
    }
}
// runner.
