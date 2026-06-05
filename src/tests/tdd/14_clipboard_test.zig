//! Ladder step 14 — **clipboard** (`getClipboardText` / `setClipboardText`).
//! *(v0.8.0)* Needs step 1 (`init`). The set→get round-trip is provable
//! in-process on a desktop session; headless CI has no clipboard, so it stays
//! gated until the backend lands. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .getClipboardText = false,
    .setClipboardText = false,
};

// WHEN setting then reading clipboard text · GIVEN a started platform · THEN the read text equals what was set.
test "clipboard: set then get round-trips" {
    try gate(done.setClipboardText and done.getClipboardText);
    try h.startup();
    defer platform.deinit();
    try platform.setClipboardText("tdd-clip");
    const got = try platform.getClipboardText(std.testing.allocator);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings("tdd-clip", got);
}

// WHEN reading the clipboard · GIVEN a started platform · THEN an owned slice is returned (freeable, no leak).
test "clipboard: get returns an owned slice" {
    try gate(done.getClipboardText);
    try h.startup();
    defer platform.deinit();
    const got = try platform.getClipboardText(std.testing.allocator);
    std.testing.allocator.free(got);
}
