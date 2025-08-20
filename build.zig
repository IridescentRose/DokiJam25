const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl3dep = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });
    const zmath = b.dependency("zmath", .{
        .target = target,
        .optimize = optimize,
        .enable_cross_platform_determinism = true,
    });
    const znoise = b.dependency("znoise", .{
        .target = target,
        .optimize = optimize,
    });
    const zaudio = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });
    const tracy = b.dependency("tracy", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "DokiJam25",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{ .{
                .name = "sdl3",
                .module = sdl3dep.module("sdl3"),
            }, .{
                .name = "zmath",
                .module = zmath.module("root"),
            }, .{
                .name = "znoise",
                .module = znoise.module("root"),
            }, .{
                .name = "zaudio",
                .module = zaudio.module("root"),
            }, .{
                .name = "tracy",
                .module = tracy.module("tracy"),
            } },
        }),
    });

    // Allow the user to enable or disable Tracy support with a build flag
    const tracy_enabled = b.option(
        bool,
        "tracy",
        "Build with Tracy support.",
    ) orelse false;

    if (tracy_enabled) {
        // The user asked to enable Tracy, use the real implementation
        exe.root_module.addImport("tracy_impl", tracy.module("tracy_impl_enabled"));
    } else {
        // The user asked to disable Tracy, use the dummy implementation
        exe.root_module.addImport("tracy_impl", tracy.module("tracy_impl_disabled"));
    }

    // exe.subsystem = .Windows;
    exe.root_module.addCSourceFile(.{
        .file = b.path("src/stbi/stbi.c"),
        .flags = &[_][]const u8{"-g"},
        .language = .c,
    });
    exe.root_module.addIncludePath(b.path("src/stbi/"));
    exe.linkLibC();
    exe.linkLibrary(znoise.artifact("FastNoiseLite"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
