//! Ladder step 13 — **OpenGL context** (`glCreateContext` / `glMakeCurrent` /
//! `glSwapWindow` / `glSetSwapInterval` / `glGetProcAddress` / `glDestroyContext`).
//! *(v0.6.0)* Needs step 1 (`init`) and step 3 (`Window`, created with
//! `renderer = .opengl`). These need a real GL-capable display, so they run in
//! a windowed CI leg (or locally), not headless; the e2e "pixels actually
//! present" check is in `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .glCreateContext = false,
    .glMakeCurrent = false,
    .glSwapWindow = false,
    .glSetSwapInterval = false,
    .glGetProcAddress = false,
    .glDestroyContext = false,
};

/// A window created on the OpenGL renderer path — the precondition for every
/// GL-context call. Caller defers `window.destroy()`.
fn glWindow() !*platform.Window {
    return platform.Window.create(.{ .title = "tdd-gl", .renderer = .opengl });
}

// --- glCreateContext -------------------------------------------------------

// WHEN calling glCreateContext on an `.opengl` window · GIVEN a started platform · THEN it returns a non-null context the caller owns.
test "glCreateContext: returns a context for an .opengl window" {
    try gate(done.glCreateContext);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const ctx = try platform.glCreateContext(window);
    defer platform.glDestroyContext(ctx);
}

// --- glMakeCurrent ---------------------------------------------------------

// WHEN making a freshly created context current on its window · GIVEN an `.opengl` window + context · THEN it succeeds.
test "glMakeCurrent: binds a context to its window without error" {
    try gate(done.glCreateContext and done.glMakeCurrent);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const ctx = try platform.glCreateContext(window);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(window, ctx);
}

// --- glSwapWindow ----------------------------------------------------------

// WHEN calling glSwapWindow after making a context current · GIVEN an `.opengl` window with a current context · THEN it presents the back buffer without error.
test "glSwapWindow: presents the back buffer of a current context" {
    try gate(done.glCreateContext and done.glMakeCurrent and done.glSwapWindow);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const ctx = try platform.glCreateContext(window);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(window, ctx);
    platform.glSwapWindow(window);
}

// --- glSetSwapInterval -----------------------------------------------------

// WHEN setting the swap interval to vsync (1) then off (0) · GIVEN a current GL context · THEN both calls are accepted.
test "glSetSwapInterval: accepts vsync (1) and off (0)" {
    try gate(done.glCreateContext and done.glMakeCurrent and done.glSetSwapInterval);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const ctx = try platform.glCreateContext(window);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(window, ctx);
    platform.glSetSwapInterval(1);
    platform.glSetSwapInterval(0);
}

// --- glGetProcAddress ------------------------------------------------------

// WHEN resolving a core GL symbol ("glClear") with a current context · GIVEN a current GL context · THEN a non-null function address is returned.
test "glGetProcAddress: resolves a core GL symbol" {
    try gate(done.glCreateContext and done.glMakeCurrent and done.glGetProcAddress);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const ctx = try platform.glCreateContext(window);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(window, ctx);
    try std.testing.expect(platform.glGetProcAddress("glClear") != null);
}

// WHEN resolving a bogus symbol ("glNotARealFunction") · GIVEN a current GL context · THEN null is returned.
test "glGetProcAddress: an unknown symbol resolves to null" {
    try gate(done.glCreateContext and done.glMakeCurrent and done.glGetProcAddress);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const ctx = try platform.glCreateContext(window);
    defer platform.glDestroyContext(ctx);
    try platform.glMakeCurrent(window, ctx);
    try std.testing.expect(platform.glGetProcAddress("glNotARealFunction") == null);
}

// --- glDestroyContext ------------------------------------------------------

// WHEN creating then destroying a context · GIVEN an `.opengl` window · THEN a fresh context can be created again afterwards (clean teardown).
test "glDestroyContext: a context can be created again after teardown" {
    try gate(done.glCreateContext and done.glDestroyContext);
    try h.startup();
    defer platform.deinit();
    const window = try glWindow();
    defer window.destroy();
    const first = try platform.glCreateContext(window);
    platform.glDestroyContext(first);
    const second = try platform.glCreateContext(window);
    defer platform.glDestroyContext(second);
}
