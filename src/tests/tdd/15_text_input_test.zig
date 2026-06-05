//! Ladder step 15 — **text input / IME** (`Window.startTextInput` /
//! `stopTextInput` / `textInputActive`). *(v0.8.0)* Needs step 1 (`init`) +
//! step 3 (`Window`). The active-flag toggle is provable in-process; actual IME
//! composition (`text_input` events) is a manual e2e in `docs/manual-testing.md`.
//! See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .startTextInput = false,
    .stopTextInput = false,
    .textInputActive = false,
};

// WHEN starting then stopping text input · GIVEN a window · THEN textInputActive tracks the state (true after start, false after stop).
test "text input: start activates, stop deactivates" {
    try gate(done.startTextInput and done.stopTextInput and done.textInputActive);
    try h.startup();
    defer platform.deinit();
    const window = try h.headlessWindow();
    defer window.destroy();
    window.startTextInput();
    try std.testing.expect(window.textInputActive());
    window.stopTextInput();
    try std.testing.expect(!window.textInputActive());
}
