//! Ladder — **window state** (runtime `setFullscreen`/`setResizable`/
//! `setBordered`/`setMinSize`/`setMaxSize` + their getters, and
//! `minimize`/`maximize`/`restore`/`raise`). *(v0.7.0)* Needs step 3 (window
//! create). SDL tracks the resizable/bordered flags and the min/max size
//! independently of the WM, so those round-trips are asserted; fullscreen and
//! the minimize/maximize/restore/raise transitions are WM-mediated, so they're
//! exercised as smoke tests that must leave the window valid. Visual checks are
//! in `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .setResizable = true,
    .isResizable = true,
    .setBordered = true,
    .isBordered = true,
    .setMinSize = true,
    .minSize = true,
    .setMaxSize = true,
    .maxSize = true,
    .setFullscreen = true,
    .isFullscreen = true,
    .minimize = true,
    .maximize = true,
    .restore = true,
    .raise = true,
};

// --- resizable --------------------------------------------------------------

// WHEN reading isResizable on a window created resizable · GIVEN the default WindowOptions (resizable = true) · THEN it reports true.
test "isResizable: a resizable window reports resizable" {
    try gate(done.isResizable);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .resizable = true, .renderer = .none });
    defer win.destroy();
    try std.testing.expect(win.isResizable());
}

// WHEN creating a window with resizable = false · GIVEN a started platform · THEN isResizable reports false.
test "isResizable: a fixed-size window reports not resizable" {
    try gate(done.isResizable);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .resizable = false, .renderer = .none });
    defer win.destroy();
    try std.testing.expect(!win.isResizable());
}

// WHEN toggling setResizable(false) then setResizable(true) · GIVEN a resizable window · THEN isResizable tracks each change.
test "setResizable: toggles the resizable flag both ways" {
    try gate(done.setResizable and done.isResizable);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .resizable = true, .renderer = .none });
    defer win.destroy();
    win.setResizable(false);
    try std.testing.expect(!win.isResizable());
    win.setResizable(true);
    try std.testing.expect(win.isResizable());
}

// --- bordered ---------------------------------------------------------------

// WHEN reading isBordered on a normal (non-borderless) window · GIVEN borderless = false at create · THEN it reports true.
test "isBordered: a decorated window reports bordered" {
    try gate(done.isBordered);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .borderless = false, .renderer = .none });
    defer win.destroy();
    try std.testing.expect(win.isBordered());
}

// WHEN calling setBordered(false) then setBordered(true) · GIVEN a decorated window · THEN isBordered tracks each change.
test "setBordered: toggles the border both ways" {
    try gate(done.setBordered and done.isBordered);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .borderless = false, .renderer = .none });
    defer win.destroy();
    win.setBordered(false);
    try std.testing.expect(!win.isBordered());
    win.setBordered(true);
    try std.testing.expect(win.isBordered());
}

// --- min / max size ---------------------------------------------------------

// WHEN setting a minimum size of 200x150 and reading it back · GIVEN a window · THEN minSize equals 200x150.
test "setMinSize: the minimum size round-trips" {
    try gate(done.setMinSize and done.minSize);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.setMinSize(.{ .w = 200, .h = 150 });
    const m = win.minSize();
    try std.testing.expectEqual(@as(u32, 200), m.w);
    try std.testing.expectEqual(@as(u32, 150), m.h);
}

// WHEN setting a maximum size of 1000x800 and reading it back · GIVEN a window · THEN maxSize equals 1000x800.
test "setMaxSize: the maximum size round-trips" {
    try gate(done.setMaxSize and done.maxSize);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.setMaxSize(.{ .w = 1000, .h = 800 });
    const m = win.maxSize();
    try std.testing.expectEqual(@as(u32, 1000), m.w);
    try std.testing.expectEqual(@as(u32, 800), m.h);
}

// WHEN reading minSize on a freshly created window · GIVEN no min size was set · THEN it reports 0x0 (no constraint).
test "minSize: defaults to no constraint" {
    try gate(done.minSize);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    const m = win.minSize();
    try std.testing.expectEqual(@as(u32, 0), m.w);
    try std.testing.expectEqual(@as(u32, 0), m.h);
}

// --- fullscreen -------------------------------------------------------------

// WHEN reading isFullscreen on a normal window · GIVEN fullscreen = false at create · THEN it reports false.
test "isFullscreen: a windowed window reports not fullscreen" {
    try gate(done.isFullscreen);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(!win.isFullscreen());
}

// WHEN entering then leaving fullscreen · GIVEN a windowed window · THEN the window ends up windowed again and still reports a positive size.
test "setFullscreen: a fullscreen→windowed cycle leaves the window valid and windowed" {
    try gate(done.setFullscreen and done.isFullscreen);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.setFullscreen(true);
    win.setFullscreen(false);
    try std.testing.expect(!win.isFullscreen());
    try std.testing.expect(win.size().w > 0);
}

// --- minimize / maximize / restore / raise (WM-mediated smoke) --------------

// WHEN calling maximize then restore · GIVEN a window · THEN the window survives and still reports a positive size.
test "maximize/restore: the cycle leaves the window valid" {
    try gate(done.maximize and done.restore);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.maximize();
    win.restore();
    try std.testing.expect(win.size().w > 0);
}

// WHEN calling minimize then restore · GIVEN a window · THEN the window survives and still reports a positive size.
test "minimize/restore: the cycle leaves the window valid" {
    try gate(done.minimize and done.restore);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.minimize();
    win.restore();
    try std.testing.expect(win.size().w > 0);
}

// WHEN calling raise on a window · GIVEN a started platform · THEN the call returns and the window remains valid.
test "raise: raising a window is a safe no-crash call" {
    try gate(done.raise);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.raise();
    try std.testing.expect(win.size().w > 0);
}
