//! Shared helpers for the ordered TDD suite (`src/tests/tdd/`).
//!
//! Every test in this suite calls `try gate(done.<fn>)` first: until you flip
//! that function's `done` flag to `true`, the test **skips**; once flipped it
//! **must pass** (the definition of done). See `CONTRIBUTING.md` for the ladder
//! order and the contributor workflow.

const std = @import("std");
const platform = @import("platform");

/// Skip a test until the function it covers is implemented. Pass the relevant
/// `done.<fn>` flag (or an `and` of several when a test exercises more than one).
pub fn gate(implemented: bool) error{SkipZigTest}!void {
    if (!implemented) return error.SkipZigTest;
}

/// Bring the backend up for a test body; caller defers `platform.deinit()`.
pub fn startup() !void {
    try platform.init(.{});
}

/// A headless (`renderer = .none`) window for window/event/handoff tests.
pub fn headlessWindow() !*platform.Window {
    return platform.Window.create(.{ .title = "tdd", .renderer = .none });
}
