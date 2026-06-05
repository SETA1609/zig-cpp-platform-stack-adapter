//! Ladder step 17 — **power info** (`powerInfo`). *(v0.8.0)* Needs step 1
//! (`init`). The shape + invariants are provable anywhere; the *specific*
//! values are environment truths. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .powerInfo = false,
};

// WHEN querying power info · GIVEN a started platform · THEN it returns a state, and a present battery percent is within 0..=100.
test "power: returns a state with a sane battery percent" {
    try gate(done.powerInfo);
    try h.startup();
    defer platform.deinit();
    const info = platform.powerInfo();
    _ = info.state;
    if (info.percent) |pct| try std.testing.expect(pct <= 100);
}

// WHEN no battery is reported · GIVEN a `no_battery` state · THEN percent and seconds are null (consistent reporting).
test "power: no_battery implies null percent + seconds" {
    try gate(done.powerInfo);
    try h.startup();
    defer platform.deinit();
    const info = platform.powerInfo();
    if (info.state == .no_battery) {
        try std.testing.expect(info.percent == null);
        try std.testing.expect(info.seconds == null);
    }
}
