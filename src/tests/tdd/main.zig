//! Aggregator for the ordered TDD suite — `zig build test-tdd` runs every file
//! referenced here. Files are listed in **ladder order** (the order to
//! implement them in); each step's functions depend on the steps above it. See
//! `CONTRIBUTING.md`.
//!
//! All tests skip by default and turn on per-function via the `done` flags at
//! the top of each file — so this step is **green (all skipped)** until a
//! contributor implements a function and flips its flag.

test {
    _ = @import("01_lifecycle_test.zig");
    _ = @import("02_time_test.zig");
    _ = @import("03_window_test.zig");
    _ = @import("04_events_test.zig");
    _ = @import("05_binding_test.zig");
    _ = @import("06_vulkan_handoff_test.zig");
    _ = @import("07_action_test.zig");
    _ = @import("08_context_test.zig");
    _ = @import("09_capabilities_test.zig");
    _ = @import("10_paths_test.zig");
}
