//! Ladder — **mouse & cursor** (global cursor visibility:
//! `showCursor`/`hideCursor`/`cursorVisible`; per-window
//! `setRelativeMouseMode`/`relativeMouseMode` for FPS-style capture,
//! `warpMouse`, and `setMouseGrab`/`mouseGrabbed`). *(v0.7.0)* Needs step 3
//! (window create) for the per-window calls. SDL tracks the relative-mode and
//! grab flags and the global cursor-visibility state, so those round-trips are
//! asserted; `warpMouse` is a no-crash smoke test (the resulting pointer
//! position is WM-mediated). See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .showCursor = true,
    .hideCursor = true,
    .cursorVisible = true,
    .setRelativeMouseMode = true,
    .relativeMouseMode = true,
    .warpMouse = true,
    .setMouseGrab = true,
    .mouseGrabbed = true,
};

// --- global cursor visibility -----------------------------------------------

// WHEN calling hideCursor · GIVEN a started platform · THEN cursorVisible reports false.
test "hideCursor: hiding the cursor makes it not visible" {
    try gate(done.hideCursor and done.cursorVisible);
    try h.startup();
    defer platform.deinit();
    defer platform.showCursor(); // restore global state for later tests
    platform.hideCursor();
    try std.testing.expect(!platform.cursorVisible());
}

// WHEN calling showCursor after hiding · GIVEN the cursor was hidden · THEN cursorVisible reports true.
test "showCursor: showing the cursor makes it visible again" {
    try gate(done.showCursor and done.hideCursor and done.cursorVisible);
    try h.startup();
    defer platform.deinit();
    platform.hideCursor();
    platform.showCursor();
    try std.testing.expect(platform.cursorVisible());
}

// WHEN hiding then showing the cursor · GIVEN a started platform · THEN the visibility round-trips back to visible.
test "cursorVisible: hide→show round-trips to visible" {
    try gate(done.showCursor and done.hideCursor and done.cursorVisible);
    try h.startup();
    defer platform.deinit();
    platform.hideCursor();
    try std.testing.expect(!platform.cursorVisible());
    platform.showCursor();
    try std.testing.expect(platform.cursorVisible());
}

// --- relative mouse mode (capture) ------------------------------------------

// WHEN reading relativeMouseMode on a fresh window · GIVEN relative mode was never enabled · THEN it reports false.
test "relativeMouseMode: defaults to off" {
    try gate(done.relativeMouseMode);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(!win.relativeMouseMode());
}

// WHEN enabling relative mouse mode · GIVEN a window · THEN relativeMouseMode reports true.
test "setRelativeMouseMode: enabling it is reflected by the query" {
    try gate(done.setRelativeMouseMode and done.relativeMouseMode);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.setRelativeMouseMode(true);
    try std.testing.expect(win.relativeMouseMode());
}

// WHEN enabling then disabling relative mouse mode · GIVEN a window · THEN the mode round-trips back to off.
test "setRelativeMouseMode: on→off round-trips" {
    try gate(done.setRelativeMouseMode and done.relativeMouseMode);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.setRelativeMouseMode(true);
    win.setRelativeMouseMode(false);
    try std.testing.expect(!win.relativeMouseMode());
}

// --- mouse grab -------------------------------------------------------------

// WHEN reading mouseGrabbed on a fresh window · GIVEN grab was never enabled · THEN it reports false.
test "mouseGrabbed: defaults to off" {
    try gate(done.mouseGrabbed);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    try std.testing.expect(!win.mouseGrabbed());
}

// WHEN enabling then disabling mouse grab · GIVEN a window · THEN mouseGrabbed tracks each change.
test "setMouseGrab: toggles the grab flag both ways" {
    try gate(done.setMouseGrab and done.mouseGrabbed);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.setMouseGrab(true);
    try std.testing.expect(win.mouseGrabbed());
    win.setMouseGrab(false);
    try std.testing.expect(!win.mouseGrabbed());
}

// --- warp -------------------------------------------------------------------

// WHEN warping the pointer to a position inside the window · GIVEN a window · THEN the call returns and the window remains valid.
test "warpMouse: warping is a safe no-crash call" {
    try gate(done.warpMouse);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    win.warpMouse(10.0, 20.0);
    try std.testing.expect(win.size().w > 0);
}
