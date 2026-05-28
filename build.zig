//! Build script for zig-cpp-platform-stack-adapter.
//!
//! Produces two things downstream consumes:
//!   1. A Zig module named "platform" (the public API in src/root.zig).
//!   2. A static-library artifact named "platform" that bundles the compiled
//!      Zig glue and links SDL3 (built via castholm/SDL).
//!
//! Downstream apps import the module for the API and `linkLibrary` the
//! artifact to pull in SDL3 transitively — see ../README.md for the
//! libs-first / link-the-artifact model.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // SDL3 packaged for the Zig build system. Pinned in build.zig.zon.
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    // Public Zig API. `addModule` registers it under the name "platform"
    // so downstream `b.dependency("platform", ...).module("platform")`
    // resolves it.
    const platform_mod = b.addModule("platform", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    platform_mod.linkLibrary(sdl_lib);

    // Static-library artifact. Downstream `linkLibrary` on this pulls in
    // the compiled Zig glue and (transitively) SDL3.
    const platform_lib = b.addLibrary(.{
        .name = "platform",
        .linkage = .static,
        .root_module = platform_mod,
    });
    b.installArtifact(platform_lib);
}
