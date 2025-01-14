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

    const day04 = b.createModule(.{
        .root_source_file = b.path("src/day04/day04.zig"),
        .target = target,
        .optimize = optimize,
    });

    const day05 = b.createModule(.{
        .root_source_file = b.path("src/day05/day05.zig"),
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

    const day04_exe = b.addExecutable(.{
        .name = "day04",
        .root_module = day04,
    });

    const day05_exe = b.addExecutable(.{
        .name = "day05",
        .root_module = day05,
    });

    b.installArtifact(day01_exe);
    b.installArtifact(day02_exe);
    b.installArtifact(day03_exe);
    b.installArtifact(day04_exe);
    b.installArtifact(day05_exe);
}
// runner.
