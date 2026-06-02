//! Ladder step 10 — **filesystem paths** (`applicationDataDirectory` / `applicationCacheDirectory`).
//! *(v0.8.0)* Needs step 1 (`init`). The path *shape* is provable here; that
//! the data dir actually persists across runs is an e2e check in
//! `docs/manual-testing.md`. `openWithSystemDefault` is manual-only (it launches
//! an external app). See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .applicationDataDirectory = false,
    .applicationCacheDirectory = false,
};

// WHEN calling applicationDataDirectory for "tdd-app" · GIVEN a started platform · THEN it returns an owned path of non-zero length.
test "applicationDataDirectory: returns a non-empty owned path" {
    try gate(done.applicationDataDirectory);
    try h.startup();
    defer platform.deinit();
    const p = try platform.applicationDataDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(p.len > 0);
}

// WHEN calling applicationDataDirectory for "tdd-app" · GIVEN a started platform · THEN the returned path contains the app name "tdd-app".
test "applicationDataDirectory: the path includes the app name" {
    try gate(done.applicationDataDirectory);
    try h.startup();
    defer platform.deinit();
    const p = try platform.applicationDataDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(std.mem.indexOf(u8, p, "tdd-app") != null);
}

// WHEN calling applicationDataDirectory twice for the same "tdd-app" · GIVEN a started platform · THEN both calls return identical paths.
test "applicationDataDirectory: is deterministic for the same app name" {
    try gate(done.applicationDataDirectory);
    try h.startup();
    defer platform.deinit();
    const a = try platform.applicationDataDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(a);
    const b = try platform.applicationDataDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings(a, b);
}

// WHEN calling applicationCacheDirectory for "tdd-app" · GIVEN a started platform · THEN it returns an owned path of non-zero length.
test "applicationCacheDirectory: returns a non-empty owned path" {
    try gate(done.applicationCacheDirectory);
    try h.startup();
    defer platform.deinit();
    const p = try platform.applicationCacheDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(p.len > 0);
}

// WHEN calling applicationCacheDirectory for "tdd-app" · GIVEN a started platform · THEN the returned path contains the app name "tdd-app".
test "applicationCacheDirectory: the path includes the app name" {
    try gate(done.applicationCacheDirectory);
    try h.startup();
    defer platform.deinit();
    const p = try platform.applicationCacheDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(std.mem.indexOf(u8, p, "tdd-app") != null);
}

// WHEN comparing applicationCacheDirectory and applicationDataDirectory for "tdd-app" · GIVEN a started platform · THEN the cache path differs from the persistent data path.
test "applicationCacheDirectory: differs from the persistent data dir" {
    try gate(done.applicationDataDirectory and done.applicationCacheDirectory);
    try h.startup();
    defer platform.deinit();
    const data = try platform.applicationDataDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(data);
    const cache = try platform.applicationCacheDirectory(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(cache);
    try std.testing.expect(!std.mem.eql(u8, data, cache));
}
