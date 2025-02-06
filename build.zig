const std = @import("std");

const eql = std.mem.eql;

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
    "day11",
    "day12",
    "day13",
    "day14",
    "day15",
    "day16",
    "day17",
    "day18",
    "day19",
    "day20",
    "day21",
    "day22",
    "day23",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const raylib_dep = b.dependency("raylib-zig", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const raylib = raylib_dep.module("raylib"); // main raylib module
    // const raygui = raylib_dep.module("raygui"); // raygui module
    // const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

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
        // if (eql(u8, day, "day21") or eql(u8, day, "day14")) {
        //     exe.linkLibrary(raylib_artifact);
        //     exe.root_module.addImport("raylib", raylib);
        //     exe.root_module.addImport("raygui", raygui);
        // }

        b.installArtifact(exe);
        const exec_check = b.addExecutable(.{
            .name = day,
            .root_module = module,
        });
        check_step.dependOn(&exec_check.step);
    }
}
// runner.
