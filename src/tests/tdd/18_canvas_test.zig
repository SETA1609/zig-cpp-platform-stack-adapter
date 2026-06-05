//! Ladder step 18 — **2D canvas** (`Canvas.create`/`destroy`/`clear`/`fillRect`/
//! `drawLine`/`copy`/`present` + `loadTexture`). *(v0.9.0)* Needs step 1
//! (`init`) + step 3 (`Window`). The default `Color` alpha is provable
//! in-process; the draw path needs a real renderer/display, so it stays gated
//! and is signed off visually in `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .create = false,
    .clear = false,
    .fillRect = false,
    .drawLine = false,
    .present = false,
};

// WHEN constructing a Color without alpha · GIVEN the 2D types · THEN alpha defaults to opaque (255).
test "canvas: Color alpha defaults to opaque" {
    try gate(done.create);
    const color: platform.Color = .{ .r = 1, .g = 2, .b = 3 };
    try std.testing.expectEqual(@as(u8, 255), color.a);
}

// WHEN creating a canvas and drawing a frame · GIVEN a window · THEN clear/fillRect/drawLine/present all succeed.
test "canvas: create, draw a frame, present" {
    try gate(done.create and done.clear and done.fillRect and done.drawLine and done.present);
    try h.startup();
    defer platform.deinit();
    const window = try h.headlessWindow();
    defer window.destroy();
    const canvas = try platform.Canvas.create(window);
    defer canvas.destroy();
    canvas.clear(.{ .r = 0, .g = 0, .b = 0 });
    canvas.fillRect(.{ .x = 0, .y = 0, .w = 10, .h = 10 }, .{ .r = 255, .g = 0, .b = 0 });
    canvas.drawLine(0, 0, 10, 10, .{ .r = 0, .g = 255, .b = 0 });
    canvas.present();
}
