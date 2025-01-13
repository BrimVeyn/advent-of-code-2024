const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const day01 = b.createModule(.{
        .root_source_file = b.path("src/day01/day01.zig"),
        .target = target,
        .optimize = optimize,
    });

    const day02 = b.createModule(.{
        .root_source_file = b.path("src/day02/day02.zig"),
        .target = target,
        .optimize = optimize,
    });

    const day03 = b.createModule(.{
        .root_source_file = b.path("src/day03/day03.zig"),
        .target = target,
        .optimize = optimize,
    });

    const day01_exe = b.addExecutable(.{
        .name = "day01",
        .root_module = day01,
    });

    const day02_exe = b.addExecutable(.{
        .name = "day02",
        .root_module = day02,
    });

    const day03_exe = b.addExecutable(.{
        .name = "day03",
        .root_module = day03,
    });

    b.installArtifact(day01_exe);
    b.installArtifact(day02_exe);
    b.installArtifact(day03_exe);
}
// runner.
