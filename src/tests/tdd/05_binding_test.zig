//! Ladder step 5 — **action bindings** (`bindAction` / `unbindAction`).
//! *(v0.6.0 for keys)* Needs step 1 (`init`). These prove the calls accept
//! every binding shape; that a bound *physical key* actually drives the action
//! needs real input and is in `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

/// The action vocabulary is the *consumer's* — the library names none. This
/// test stands in for a game defining its own enum and passing it to the lib.
const Action = enum(u16) { move_forward, jump, interact, menu_pause };

const done = .{
    .bindAction = true,
    .unbindAction = true,
};

// WHEN binding an action to a key (escape) · GIVEN a started platform · THEN bindAction accepts the binding without error.
test "bindAction: a key binding is accepted" {
    try gate(done.bindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(Action.menu_pause, .{ .key = .escape });
}

// WHEN binding an action to a mouse button (left) · GIVEN a started platform · THEN bindAction accepts the binding without error.
test "bindAction: a mouse-button binding is accepted" {
    try gate(done.bindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(Action.interact, .{ .mouse_button = .left });
}

// WHEN binding an action to a composite any-of (W or Up) binding · GIVEN a started platform · THEN bindAction accepts the binding without error.
test "bindAction: a composite any-of binding is accepted" {
    try gate(done.bindAction);
    try h.startup();
    defer platform.deinit();
    const any_of = [_]platform.ActionBinding{ .{ .key = .w }, .{ .key = .up } };
    platform.bindAction(Action.move_forward, .{ .composite = &any_of });
}

// WHEN unbinding the same key binding that was just bound · GIVEN a started platform · THEN unbindAction accepts the removal without error.
test "unbindAction: removing a previously-added binding is accepted" {
    try gate(done.bindAction and done.unbindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(Action.menu_pause, .{ .key = .escape });
    platform.unbindAction(Action.menu_pause, .{ .key = .escape });
}

// WHEN unbinding one of two keys (enter) bound to the same action · GIVEN a started platform · THEN unbindAction accepts the removal without error.
test "unbindAction: removing one of two bindings leaves the call well-formed" {
    try gate(done.bindAction and done.unbindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(Action.jump, .{ .key = .space });
    platform.bindAction(Action.jump, .{ .key = .enter });
    platform.unbindAction(Action.jump, .{ .key = .enter });
}

// WHEN unbinding a binding that was never added · GIVEN a started platform · THEN unbindAction is a safe no-op (no error).
test "unbindAction: unbinding a never-bound action is safe" {
    try gate(done.unbindAction);
    try h.startup();
    defer platform.deinit();
    platform.unbindAction(Action.interact, .{ .key = .f });
}
