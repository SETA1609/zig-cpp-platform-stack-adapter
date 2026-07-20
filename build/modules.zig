//! Module and library creation for the platform-stack adapter.
//!
//! Creates the `platform` Zig module (`src/root.zig`), pulls in the SDL3
//! dependency as a static library, and produces the `platform` static-link
//! artifact that downstream (zGameLib) `linkLibrary`s.

const std = @import("std");

/// Windowing backends. SDL3 is the active backend; native per-OS is
/// planned post-1.0 (X11, Wayland, Win32, Cocoa, Android NDK).
pub const Backend = enum(u1) {
    sdl3,
    native,

    pub const all = [_]Backend{ .sdl3, .native };
};

pub const Modules = struct {
    platform_mod: *std.Build.Module,
    platform_lib: *std.Build.Step.Compile,
    sdl_lib: *std.Build.Step.Compile,
    backend: Backend,
};

fn parseBackend(opt: []const u8) Backend {
    const b = std.meta.stringToEnum(Backend, opt) orelse
        std.debug.panic("Unknown backend '{s}'. Valid: sdl3, native", .{opt});
    return b;
}

pub fn create(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Modules {
    const backend_opt = b.option([]const u8, "backend",
        "Windowing backend: sdl3, native (default: sdl3)") orelse "sdl3";
    const backend = parseBackend(backend_opt);

    const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });
    const sdl_lib = sdl_dep.artifact("SDL3");

    const platform_mod = b.addModule("platform", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    platform_mod.linkLibrary(sdl_lib);

    const build_config = b.addOptions();
    inline for (@typeInfo(Backend).@"enum".fields) |field| {
        const p: Backend = @enumFromInt(field.value);
        build_config.addOption(bool, b.fmt("backend_{s}", .{field.name}), p == backend);
    }
    platform_mod.addOptions("build_config", build_config);

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
        .backend = backend,
    };
}
