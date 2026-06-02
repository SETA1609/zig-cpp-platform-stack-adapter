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

// WHEN injecting jump as pressed then polling · GIVEN a started platform · THEN actionPressed(jump) is true.
test "actionPressed: true after a pressed injection" {
    try gate(done.injectAction and done.actionPressed);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expect(platform.actionPressed(Action.jump));
}

// WHEN injecting jump as released then polling · GIVEN a started platform · THEN actionPressed(jump) is false.
test "actionPressed: false after a released injection" {
    try gate(done.injectAction and done.actionPressed);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, false, 0.0);
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionPressed(Action.jump));
}

// WHEN injecting jump as pressed then polling · GIVEN a started platform · THEN actionPressed(interact) (a different action) stays false.
test "actionPressed: injecting one action does not press another" {
    try gate(done.injectAction and done.actionPressed);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionPressed(Action.interact));
}

// WHEN injecting jump as pressed on the frame after a released baseline · GIVEN a started platform · THEN actionJustPressed(jump) fires on the transition frame.
test "actionJustPressed: fires on the release→press transition frame" {
    try gate(done.injectAction and done.actionJustPressed);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents(); // baseline frame: released
    platform.injectAction(Action.jump, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expect(platform.actionJustPressed(Action.jump));
}

// WHEN polling a second frame while jump stays held · GIVEN it was pressed the prior frame · THEN actionJustPressed(jump) is false (no new edge).
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

// WHEN polling a frame with no injection for interact · GIVEN a started platform · THEN actionJustPressed(interact) is false.
test "actionJustPressed: false for an action never pressed" {
    try gate(done.injectAction and done.actionJustPressed);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionJustPressed(Action.interact));
}

// WHEN injecting jump released on the frame after it was pressed · GIVEN a started platform · THEN actionJustReleased(jump) fires on the transition frame.
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

// WHEN polling two frames with jump never pressed · GIVEN a started platform · THEN actionJustReleased(jump) stays false (no press→release edge).
test "actionJustReleased: does not fire while steadily released" {
    try gate(done.injectAction and done.actionJustReleased);
    try h.startup();
    defer platform.deinit();
    platform.pollAllEvents();
    platform.pollAllEvents();
    try std.testing.expect(!platform.actionJustReleased(Action.jump));
}

// WHEN injecting jump press then release across frames · GIVEN a started platform · THEN actionJustReleased(interact) (an unrelated action) is false.
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

// WHEN injecting move_forward with analog value 1.0 then polling · GIVEN a started platform · THEN actionValue(move_forward) is approximately 1.0.
test "actionValue: reflects an injected analog value of 1.0" {
    try gate(done.injectAction and done.actionValue);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.move_forward, true, 1.0);
    platform.pollAllEvents();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), platform.actionValue(Action.move_forward), 0.001);
}

// WHEN injecting move_forward with analog value 0.5 then polling · GIVEN a started platform · THEN actionValue(move_forward) is approximately 0.5.
test "actionValue: reflects a partial injected value of 0.5" {
    try gate(done.injectAction and done.actionValue);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.move_forward, true, 0.5);
    platform.pollAllEvents();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), platform.actionValue(Action.move_forward), 0.001);
}

// WHEN injecting move_forward as released with value 0.0 then polling · GIVEN a started platform · THEN actionValue(move_forward) is approximately 0.0.
test "actionValue: is 0.0 for a released action" {
    try gate(done.injectAction and done.actionValue);
    try h.startup();
    defer platform.deinit();
    platform.injectAction(Action.move_forward, false, 0.0);
    platform.pollAllEvents();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), platform.actionValue(Action.move_forward), 0.001);
}
