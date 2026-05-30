//! Ladder step 5 — **action bindings** (`bindAction` / `unbindAction`).
//! *(v0.6.0 for keys)* Needs step 1 (`init`). These prove the calls accept
//! every binding shape; that a bound *physical key* actually drives the action
//! needs real input and is in `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .bindAction = false,
    .unbindAction = false,
};

test "bindAction: a key binding is accepted" {
    try gate(done.bindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(.menu_pause, .{ .key = .escape });
}

test "bindAction: a mouse-button binding is accepted" {
    try gate(done.bindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(.interact, .{ .mouse_button = .left });
}

test "bindAction: a composite any-of binding is accepted" {
    try gate(done.bindAction);
    try h.startup();
    defer platform.deinit();
    const any_of = [_]platform.ActionBinding{ .{ .key = .w }, .{ .key = .up } };
    platform.bindAction(.move_forward, .{ .composite = &any_of });
}

test "unbindAction: removing a previously-added binding is accepted" {
    try gate(done.bindAction and done.unbindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(.menu_pause, .{ .key = .escape });
    platform.unbindAction(.menu_pause, .{ .key = .escape });
}

test "unbindAction: removing one of two bindings leaves the call well-formed" {
    try gate(done.bindAction and done.unbindAction);
    try h.startup();
    defer platform.deinit();
    platform.bindAction(.jump, .{ .key = .space });
    platform.bindAction(.jump, .{ .key = .enter });
    platform.unbindAction(.jump, .{ .key = .enter });
}

test "unbindAction: unbinding a never-bound action is safe" {
    try gate(done.unbindAction);
    try h.startup();
    defer platform.deinit();
    platform.unbindAction(.interact, .{ .key = .f });
}
