const std = @import("std");

pub const Modules = struct {
    platform_mod: *std.Build.Module,
    platform_lib: *std.Build.Step.Compile,
    sdl_lib: *std.Build.Step.Compile,
};

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Modules {
    const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const platform_mod = b.addModule("platform", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    platform_mod.linkLibrary(sdl_lib);

    const platform_lib = b.addLibrary(.{
        .name = "platform",
        .linkage = .static,
        .root_module = platform_mod,
    });
    b.installArtifact(platform_lib);

    return .{
        .platform_mod = platform_mod,
        .platform_lib = platform_lib,
        .sdl_lib = sdl_lib,
    };
}
