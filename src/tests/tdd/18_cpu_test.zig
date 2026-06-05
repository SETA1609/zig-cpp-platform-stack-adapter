//! Ladder step 18 — **CPU / software framebuffer** (`windowPixels` /
//! `presentPixels`). *(v0.9.0)* The `.cpu` renderer path: SDL hands the window a
//! `SDL_Surface` you write pixels into. Needs step 1 (`init`) + step 3
//! (`Window`, created with `renderer = .cpu`). Buffer invariants are provable
//! in-process on a desktop session; visual output is signed off in
//! `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .windowPixels = false,
    .presentPixels = false,
};

/// A window on the CPU/software-framebuffer renderer path.
fn cpuWindow() !*platform.Window {
    return platform.Window.create(.{ .title = "tdd-cpu", .renderer = .cpu });
}

// WHEN borrowing a .cpu window's backbuffer · GIVEN a started platform · THEN the buffer is height*pitch bytes with pitch >= width*4 (8-bit BGRA).
test "cpu: backbuffer geometry is self-consistent" {
    try gate(done.windowPixels);
    try h.startup();
    defer platform.deinit();
    const window = try cpuWindow();
    defer window.destroy();
    const fb = try platform.windowPixels(window);
    try std.testing.expectEqual(fb.height * fb.pitch, fb.pixels.len);
    try std.testing.expect(fb.pitch >= fb.width * 4);
}

// WHEN writing a pixel then presenting · GIVEN a .cpu window · THEN the write + present succeed.
test "cpu: write a pixel and present" {
    try gate(done.windowPixels and done.presentPixels);
    try h.startup();
    defer platform.deinit();
    const window = try cpuWindow();
    defer window.destroy();
    const fb = try platform.windowPixels(window);
    if (fb.pixels.len > 0) fb.pixels[0] = 0xFF;
    platform.presentPixels(window);
}
