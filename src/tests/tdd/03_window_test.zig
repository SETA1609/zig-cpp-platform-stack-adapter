//! Ladder step 3 — **window** (`create` / `destroy` / `size` / `shouldClose` /
//! `scaleFactor` / `setSize`). *(v0.6.0)* Needs step 1 (`init`). Implement
//! `create` first — every test here opens a window. Exact-pixel and visual
//! checks (title, on-screen appearance) are in `docs/manual-testing.md`.
//!
//! Needs a display server; `size`/`setSize` round-trips assume a floating WM at
//! scale 1.0 (a tiling WM may override — see the manual doc). See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .create = false,
    .destroy = false,
    .size = false,
    .shouldClose = false,
    .scaleFactor = false,
    .setSize = false,
};

test "create: headless window is non-null" {
    try gate(done.create and done.destroy);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(@intFromPtr(win) != 0);
}

test "create: vulkan-renderer window is non-null" {
    try gate(done.create and done.destroy);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .renderer = .vulkan });
    defer win.destroy();
    try std.testing.expect(@intFromPtr(win) != 0);
}

test "create: respects a custom initial size (scale 1.0)" {
    try gate(done.create and done.destroy and done.size and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .size = .{ .w = 800, .h = 600 }, .renderer = .none });
    defer win.destroy();
    const s = win.size();
    try std.testing.expect(s.w > 0 and s.h > 0);
    if (win.scaleFactor() == 1.0) {
        try std.testing.expectEqual(@as(u32, 800), s.w);
        try std.testing.expectEqual(@as(u32, 600), s.h);
    }
}

test "destroy: create→destroy→create again succeeds" {
    try gate(done.create and done.destroy);
    try h.startup();
    defer platform.deinit();
    const a = try h.headlessWindow();
    a.destroy();
    const b = try h.headlessWindow();
    b.destroy();
}

test "destroy: two live windows destroy independently" {
    try gate(done.create and done.destroy);
    try h.startup();
    defer platform.deinit();
    const a = try h.headlessWindow();
    const b = try h.headlessWindow();
    a.destroy();
    b.destroy();
}

test "destroy: a single window tears down cleanly" {
    try gate(done.create and done.destroy);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    win.destroy();
}

test "size: reports a positive drawable size" {
    try gate(done.create and done.destroy and done.size);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .size = .{ .w = 1024, .h = 768 }, .renderer = .none });
    defer win.destroy();
    const s = win.size();
    try std.testing.expect(s.w > 0 and s.h > 0);
}

test "size: is stable across consecutive reads" {
    try gate(done.create and done.destroy and done.size);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    const a = win.size();
    const b = win.size();
    try std.testing.expectEqual(a.w, b.w);
    try std.testing.expectEqual(a.h, b.h);
}

test "size: default window matches WindowOptions default (scale 1.0)" {
    try gate(done.create and done.destroy and done.size and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .renderer = .none });
    defer win.destroy();
    const s = win.size();
    try std.testing.expect(s.w > 0 and s.h > 0);
    if (win.scaleFactor() == 1.0) {
        try std.testing.expectEqual(@as(u32, 1280), s.w);
        try std.testing.expectEqual(@as(u32, 720), s.h);
    }
}

test "shouldClose: a fresh window is not closing" {
    try gate(done.create and done.destroy and done.shouldClose);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(!win.shouldClose());
}

test "shouldClose: still false after an idle poll" {
    try gate(done.create and done.destroy and done.shouldClose);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    try std.testing.expect(!win.shouldClose());
}

test "shouldClose: independent per window" {
    try gate(done.create and done.destroy and done.shouldClose);
    try h.startup();
    defer platform.deinit();
    const a = try h.headlessWindow();
    defer a.destroy();
    const b = try h.headlessWindow();
    defer b.destroy();
    try std.testing.expect(!a.shouldClose());
    try std.testing.expect(!b.shouldClose());
}

test "scaleFactor: is positive" {
    try gate(done.create and done.destroy and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(win.scaleFactor() > 0.0);
}

test "scaleFactor: is finite (not NaN/inf)" {
    try gate(done.create and done.destroy and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(std.math.isFinite(win.scaleFactor()));
}

test "scaleFactor: is stable across reads" {
    try gate(done.create and done.destroy and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expectEqual(win.scaleFactor(), win.scaleFactor());
}

test "setSize: shrinking is reflected by size() (scale 1.0, floating WM)" {
    try gate(done.create and done.destroy and done.setSize and done.size and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .size = .{ .w = 800, .h = 600 }, .resizable = true, .renderer = .none });
    defer win.destroy();
    win.setSize(.{ .w = 640, .h = 480 });
    platform.pollAllEvents();
    if (win.scaleFactor() == 1.0) {
        const s = win.size();
        try std.testing.expectEqual(@as(u32, 640), s.w);
        try std.testing.expectEqual(@as(u32, 480), s.h);
    }
}

test "setSize: growing is reflected by size() (scale 1.0, floating WM)" {
    try gate(done.create and done.destroy and done.setSize and done.size and done.scaleFactor);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .size = .{ .w = 640, .h = 480 }, .resizable = true, .renderer = .none });
    defer win.destroy();
    win.setSize(.{ .w = 1024, .h = 768 });
    platform.pollAllEvents();
    if (win.scaleFactor() == 1.0) {
        const s = win.size();
        try std.testing.expectEqual(@as(u32, 1024), s.w);
        try std.testing.expectEqual(@as(u32, 768), s.h);
    }
}

test "setSize: keeps a positive size" {
    try gate(done.create and done.destroy and done.setSize and done.size);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .resizable = true, .renderer = .none });
    defer win.destroy();
    win.setSize(.{ .w = 900, .h = 700 });
    platform.pollAllEvents();
    const s = win.size();
    try std.testing.expect(s.w > 0 and s.h > 0);
}
