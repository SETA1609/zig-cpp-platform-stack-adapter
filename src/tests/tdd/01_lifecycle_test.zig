//! Ladder step 1 — **lifecycle** (`init` / `deinit`). *(v0.6.0)*
//!
//! Everything else in the suite calls `init` first, so this is the first thing
//! to implement. Flip `done.lifecycle` to `true` once the backend's `init`/
//! `deinit` work; these three tests must then pass. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const gate = @import("harness.zig").gate;

const done = .{
    .lifecycle = false,
};

test "init: default options succeed then deinit" {
    try gate(done.lifecycle);
    try platform.init(.{});
    platform.deinit();
}

test "init: video-only subsystem succeeds" {
    try gate(done.lifecycle);
    try platform.init(.{ .video = true, .gamepad = false, .audio = false });
    platform.deinit();
}

test "init: re-init after a clean deinit succeeds" {
    try gate(done.lifecycle);
    try platform.init(.{});
    platform.deinit();
    try platform.init(.{});
    platform.deinit();
}
