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
    .pollAllEvents = true,
    .nextEvent = true,
    .events = true,
};

// WHEN calling pollAllEvents once · GIVEN a started platform with an open window and no input · THEN it returns without error.
test "pollAllEvents: callable once without input" {
    try gate(done.pollAllEvents);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
}

// WHEN calling pollAllEvents five times in a loop · GIVEN a started platform with an open window · THEN every call returns without error.
test "pollAllEvents: callable repeatedly" {
    try gate(done.pollAllEvents);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    var i: usize = 0;
    while (i < 5) : (i += 1) platform.pollAllEvents();
}

// WHEN calling pollAllEvents on an idle frame then querying shouldClose · GIVEN a started platform with a fresh window · THEN shouldClose is false.
test "pollAllEvents: leaves a fresh window not closing" {
    try gate(done.pollAllEvents);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    try std.testing.expect(!win.shouldClose());
}

// WHEN draining nextEvent after polling an idle frame · GIVEN a started platform with no synthetic input · THEN the queue drains to null within a bounded number of pops (≤ 1024).
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

// WHEN draining nextEvent after polling an idle frame · GIVEN a started platform with no close input · THEN none of the popped events is a .close event.
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

// WHEN calling nextEvent once more after fully draining the queue · GIVEN a started platform on an idle frame · THEN it returns null.
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

// WHEN reading the events() SoA view after polling an idle frame · GIVEN a started platform with no close input · THEN close_requested is false.
test "events: a freshly pumped frame has no pending close" {
    try gate(done.pollAllEvents and done.events);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    try std.testing.expect(!platform.events().close_requested);
}

// WHEN reading the events() SoA view twice without re-polling · GIVEN a started platform on an idle frame · THEN both reads report the same close_requested and keys length (the read does not consume).
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

// WHEN reading events().keys after polling an idle frame · GIVEN a started platform with no keyboard input · THEN the keys length is 0.
test "events: idle frame queues no keyboard events" {
    try gate(done.pollAllEvents and done.events);
    try h.startup();
    defer platform.deinit();
    const win = try h.headlessWindow();
    defer win.destroy();
    platform.pollAllEvents();
    // No keyboard input was generated this frame, so no key events arrive.
    // Mouse-motion is deliberately NOT asserted: showing a window can emit a
    // genuine motion event when the pointer sits over it — that is real input,
    // not spurious, and is verified by hand (docs/manual-testing.md §2), not here.
    try std.testing.expectEqual(@as(usize, 0), platform.events().keys.len);
}
