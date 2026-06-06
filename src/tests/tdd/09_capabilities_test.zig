//! Ladder step 9 — **capabilities** (`capabilities`). *(v0.7.0)* Needs step 1
//! (`init`). Proves the query is callable and self-consistent; the *specific*
//! per-session values (e.g. `can_set_window_position == false` on Wayland) are
//! environment truths verified in `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .capabilities = true,
};

// WHEN calling capabilities and reading each field · GIVEN a started platform · THEN it returns a value exposing all expected fields (a missing/renamed one would fail to compile).
test "capabilities: callable and returns a value with all fields" {
    try gate(done.capabilities);
    try h.startup();
    defer platform.deinit();
    const caps = platform.capabilities();
    // Read each field so a missing/renamed field fails to compile.
    _ = caps.can_set_window_position;
    _ = caps.can_query_window_position;
    _ = caps.can_capture_global_input;
    _ = caps.high_dpi_scale_per_monitor;
}

// WHEN calling capabilities twice · GIVEN a started platform · THEN the can_set/can_query window-position fields match across both calls.
test "capabilities: is stable across calls" {
    try gate(done.capabilities);
    try h.startup();
    defer platform.deinit();
    const a = platform.capabilities();
    const b = platform.capabilities();
    try std.testing.expectEqual(a.can_set_window_position, b.can_set_window_position);
    try std.testing.expectEqual(a.can_query_window_position, b.can_query_window_position);
}

// WHEN inspecting the capabilities flags · GIVEN a backend that can set window position · THEN it can also query window position (set implies query).
test "capabilities: setting position implies it can be queried" {
    try gate(done.capabilities);
    try h.startup();
    defer platform.deinit();
    const caps = platform.capabilities();
    // A backend that can move a window can also report where it is.
    if (caps.can_set_window_position) try std.testing.expect(caps.can_query_window_position);
}
