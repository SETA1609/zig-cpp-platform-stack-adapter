//! Ladder step 7 — **action state machine** (`injectAction` driving
//! `actionPressed` / `actionJustPressed` / `actionJustReleased` /
//! `actionValue`). *(v0.7.0)* Needs steps 1 & 4 (`init`, `pollAllEvents`).
//!
//! `injectAction` feeds an action through the same path as real input, so the
//! query layer is provable without a keyboard. Implement `injectAction` first —
//! every query test below drives state through it. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

/// Consumer-defined action enum (the library names none).
const Action = enum(u16) { jump, interact, move_forward };

const done = .{
    .injectAction = true,
    .actionPressed = true,
    .actionJustPressed = true,
    .actionJustReleased = true,
    .actionValue = true,
};

test "actionPressed: true after a pressed injection" {
    try gate(done.injectAction and done.actionPressed);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expect(platform.actionPressed(Action.jump));
}

test "actionPressed: false after a released injection" {
    try gate(done.injectAction and done.actionPressed);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, false, 0.0);
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionPressed(Action.jump));
}

test "actionPressed: injecting one action does not press another" {
    try gate(done.injectAction and done.actionPressed);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionPressed(Action.interact));
}

test "actionJustPressed: fires on the release→press transition frame" {
    try gate(done.injectAction and done.actionJustPressed);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents(); // baseline frame: released
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expect(platform.actionJustPressed(Action.jump));
}

test "actionJustPressed: does not fire on a held frame (no new transition)" {
    try gate(done.injectAction and done.actionJustPressed);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents(); // press frame
    platform.pollAllEvents(); // held frame — no new edge
    try std.testing.expect(!platform.actionJustPressed(Action.jump));
}

test "actionJustPressed: false for an action never pressed" {
    try gate(done.injectAction and done.actionJustPressed);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionJustPressed(Action.interact));
}

test "actionJustReleased: fires on the press→release transition frame" {
    try gate(done.injectAction and done.actionJustReleased);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents(); // pressed
    platform.injectAction(Action.jump, false, 0.0);
    platform.pollAllEvents(); // released this frame
    try std.testing.expect(platform.actionJustReleased(Action.jump));
}

test "actionJustReleased: does not fire while steadily released" {
    try gate(done.injectAction and done.actionJustReleased);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents();
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionJustReleased(Action.jump));
}

test "actionJustReleased: false for an unrelated action" {
    try gate(done.injectAction and done.actionJustReleased);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    platform.injectAction(Action.jump, false, 0.0);
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionJustReleased(Action.interact));
}

test "actionValue: reflects an injected analog value of 1.0" {
    try gate(done.injectAction and done.actionValue);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.move_forward, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), platform.actionValue(Action.move_forward), 0.001);
}

test "actionValue: reflects a partial injected value of 0.5" {
    try gate(done.injectAction and done.actionValue);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.move_forward, true, 0.5);
    platform.pollAllEvents();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), platform.actionValue(Action.move_forward), 0.001);
}

test "actionValue: is 0.0 for a released action" {
    try gate(done.injectAction and done.actionValue);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.move_forward, false, 0.0);
    platform.pollAllEvents();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), platform.actionValue(Action.move_forward), 0.001);
}
