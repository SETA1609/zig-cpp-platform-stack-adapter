//! Ladder step 10 — **filesystem paths** (`appDataDir` / `appCacheDir`).
//! *(v0.8.0)* Needs step 1 (`init`). The path *shape* is provable here; that
//! the data dir actually persists across runs is an e2e check in
//! `docs/manual-testing.md`. `openWithSystemDefault` is manual-only (it launches
//! an external app). See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .appDataDir = false,
    .appCacheDir = false,
};

// WHEN calling appDataDir for "tdd-app" · GIVEN a started platform · THEN it returns an owned path of non-zero length.
test "appDataDir: returns a non-empty owned path" {
    try gate(done.appDataDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(p.len > 0);
}

// WHEN calling appDataDir for "tdd-app" · GIVEN a started platform · THEN the returned path contains the app name "tdd-app".
test "appDataDir: the path includes the app name" {
    try gate(done.appDataDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(std.mem.indexOf(u8, p, "tdd-app") != null);
}

// WHEN calling appDataDir twice for the same "tdd-app" · GIVEN a started platform · THEN both calls return identical paths.
test "appDataDir: is deterministic for the same app name" {
    try gate(done.appDataDir);
    try h.startup();
    defer platform.deinit();
    const a = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(a);
    const b = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings(a, b);
}

// WHEN calling appCacheDir for "tdd-app" · GIVEN a started platform · THEN it returns an owned path of non-zero length.
test "appCacheDir: returns a non-empty owned path" {
    try gate(done.appCacheDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appCacheDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(p.len > 0);
}

// WHEN calling appCacheDir for "tdd-app" · GIVEN a started platform · THEN the returned path contains the app name "tdd-app".
test "appCacheDir: the path includes the app name" {
    try gate(done.appCacheDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appCacheDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(std.mem.indexOf(u8, p, "tdd-app") != null);
}

// WHEN comparing appCacheDir and appDataDir for "tdd-app" · GIVEN a started platform · THEN the cache path differs from the persistent data path.
test "appCacheDir: differs from the persistent data dir" {
    try gate(done.appDataDir and done.appCacheDir);
    try h.startup();
    defer platform.deinit();
    const data = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(data);
    const cache = try platform.appCacheDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(cache);
    try std.testing.expect(!std.mem.eql(u8, data, cache));
}
