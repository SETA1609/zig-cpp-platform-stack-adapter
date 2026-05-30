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

test "appDataDir: returns a non-empty owned path" {
    try gate(done.appDataDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(p.len > 0);
}

test "appDataDir: the path includes the app name" {
    try gate(done.appDataDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appDataDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(std.mem.indexOf(u8, p, "tdd-app") != null);
}

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

test "appCacheDir: returns a non-empty owned path" {
    try gate(done.appCacheDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appCacheDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(p.len > 0);
}

test "appCacheDir: the path includes the app name" {
    try gate(done.appCacheDir);
    try h.startup();
    defer platform.deinit();
    const p = try platform.appCacheDir(std.testing.allocator, "tdd-app");
    defer std.testing.allocator.free(p);
    try std.testing.expect(std.mem.indexOf(u8, p, "tdd-app") != null);
}

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
