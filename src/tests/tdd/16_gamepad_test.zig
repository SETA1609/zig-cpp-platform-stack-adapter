//! Ladder step 16 — **gamepad devices** (`connectedGamepads` / `openGamepad` +
//! `Gamepad.close`/`name`/`rumble`/`rumbleTriggers`/`setSensorEnabled`/
//! `gyroscope`/`accelerometer`). *(v0.8.0)* Needs step 1 (`init`). These need a
//! real pad, so they self-skip when none is connected; full sign-off (rumble
//! felt, sensor values sane) is the manual e2e in `docs/manual-testing.md`.
//! See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .connectedGamepads = false,
    .openGamepad = false,
    .rumble = false,
    .setSensorEnabled = false,
};

// WHEN enumerating then opening the first connected pad · GIVEN a started platform · THEN it opens and reports a name (skips if no device is present).
test "gamepad: enumerate then open/close the first connected device" {
    try gate(done.connectedGamepads and done.openGamepad);
    try h.startup();
    defer platform.deinit();
    const ids = try platform.connectedGamepads(std.testing.allocator);
    defer std.testing.allocator.free(ids);
    if (ids.len == 0) return error.SkipZigTest; // no pad in this environment
    const pad = try platform.openGamepad(ids[0]);
    defer pad.close();
    _ = pad.name();
}

// WHEN rumbling and enabling sensors on an open pad · GIVEN a connected device · THEN the calls succeed and sensor reads return (skips if no device).
test "gamepad: rumble + sensor are callable on an open device" {
    try gate(done.openGamepad and done.rumble and done.setSensorEnabled);
    try h.startup();
    defer platform.deinit();
    const ids = try platform.connectedGamepads(std.testing.allocator);
    defer std.testing.allocator.free(ids);
    if (ids.len == 0) return error.SkipZigTest;
    const pad = try platform.openGamepad(ids[0]);
    defer pad.close();
    try pad.rumble(0.5, 0.5, 100);
    try pad.setSensorEnabled(true);
    _ = pad.gyroscope();
    _ = pad.accelerometer();
}
