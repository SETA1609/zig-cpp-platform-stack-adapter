//! Ladder step 4 — **events** (`pollAllEvents` / `nextEvent` / `events`).
//! *(v0.6.0)* Needs steps 1 & 3 (`init`, window `create`/`destroy`). These
//! prove the idle-frame invariants; real OS event *delivery* (key/mouse/resize/
//! focus/close/…) needs human input and is in `docs/manual-testing.md`. See
//! `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .pollAllEvents = false,
    .nextEvent = false,
    .events = false,
};

test "pollAllEvents: callable once without input" {
    try gate(done.pollAllEvents);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
}

test "pollAllEvents: callable repeatedly" {
    try gate(done.pollAllEvents);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    var i: usize = 0;
    while (i < 5) : (i += 1) platform.pollAllEvents();
}

test "pollAllEvents: leaves a fresh window not closing" {
    try gate(done.pollAllEvents);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    try std.testing.expect(!win.shouldClose());
}

test "nextEvent: an idle frame's queue is finite and drains" {
    try gate(done.pollAllEvents and done.nextEvent);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    // No synthetic OS input in a test, so the queue must drain to null within a
    // bounded number of pops (a window open may emit a few focus/expose events).
    var pops: usize = 0;
    while (platform.nextEvent()) |_| {
        pops += 1;
        if (pops > 1024) break;
    }
    try std.testing.expect(pops <= 1024);
}

test "nextEvent: an idle frame delivers no close event" {
    try gate(done.pollAllEvents and done.nextEvent);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    var pops: usize = 0;
    while (platform.nextEvent()) |ev| {
        try std.testing.expect(ev != .close);
        pops += 1;
        if (pops > 1024) break;
    }
}

test "nextEvent: returns null after the queue is drained" {
    try gate(done.pollAllEvents and done.nextEvent);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    var pops: usize = 0;
    while (platform.nextEvent()) |_| {
        pops += 1;
        if (pops > 1024) break;
    }
    try std.testing.expect(platform.nextEvent() == null);
}

test "events: a freshly pumped frame has no pending close" {
    try gate(done.pollAllEvents and done.events);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    try std.testing.expect(!platform.events().close_requested);
}

test "events: the SoA view is non-consuming (idempotent across two reads)" {
    try gate(done.pollAllEvents and done.events);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    const a = platform.events();
    const b = platform.events();
    try std.testing.expectEqual(a.close_requested, b.close_requested);
    try std.testing.expectEqual(a.keys.len, b.keys.len);
}

test "events: idle frame has no key/mouse-motion events queued" {
    try gate(done.pollAllEvents and done.events);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    const f = platform.events();
    try std.testing.expectEqual(@as(usize, 0), f.keys.len);
    try std.testing.expectEqual(@as(usize, 0), f.mouse_motions.len);
}
