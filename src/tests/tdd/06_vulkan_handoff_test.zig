//! Ladder step 6 — **Vulkan hand-off** (`requiredVulkanInstanceExtensions` +
//! the native-handle presence invariants). *(v0.6.0)* Needs steps 1 & 3
//! (`init`, window `create`). The *validity* of the handles (feeding them to a
//! real Vulkan surface creator) is the cross-lib e2e test in
//! `docs/manual-testing.md`. See `CONTRIBUTING.md`.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .requiredVulkanInstanceExtensions = false,
    .nativeHandles = false,
};

test "requiredVulkanInstanceExtensions: returns a non-empty list" {
    try gate(done.requiredVulkanInstanceExtensions);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.requiredVulkanInstanceExtensions().len > 0);
}

test "requiredVulkanInstanceExtensions: includes VK_KHR_surface" {
    try gate(done.requiredVulkanInstanceExtensions);
    try h.startup();
    defer platform.deinit();
    var found = false;
    for (platform.requiredVulkanInstanceExtensions()) |ext| {
        if (std.mem.eql(u8, std.mem.span(ext), "VK_KHR_surface")) found = true;
    }
    try std.testing.expect(found);
}

test "requiredVulkanInstanceExtensions: every entry is a non-empty C string" {
    try gate(done.requiredVulkanInstanceExtensions);
    try h.startup();
    defer platform.deinit();
    for (platform.requiredVulkanInstanceExtensions()) |ext| {
        try std.testing.expect(std.mem.span(ext).len > 0);
    }
}

// The native-handle getters return raw OS pointers whose *validity* only a
// Vulkan surface creator can prove (see manual doc). What IS provable in
// process: which OS's getter is live.

test "native handles: foreign-OS getters are null on Linux" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    try gate(done.nativeHandles);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .renderer = .vulkan });
    defer win.destroy();
    try std.testing.expect(platform.getWin32Handle(win) == null);
    try std.testing.expect(platform.getAndroidHandle(win) == null);
    try std.testing.expect(platform.getCocoaHandle(win) == null);
}

test "native handles: the active Linux display server exposes a handle" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    try gate(done.nativeHandles);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .renderer = .vulkan });
    defer win.destroy();
    const has_x11 = platform.getX11Handle(win) != null;
    const has_wl = platform.getWaylandHandle(win) != null;
    try std.testing.expect(has_x11 or has_wl);
}

test "native handles: a present handle carries a non-null display pointer" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    try gate(done.nativeHandles);
    try h.startup();
    defer platform.deinit();
    const win = try platform.Window.create(.{ .title = "tdd", .renderer = .vulkan });
    defer win.destroy();
    if (platform.getX11Handle(win)) |x| {
        try std.testing.expect(@intFromPtr(x.display) != 0);
    } else if (platform.getWaylandHandle(win)) |w| {
        try std.testing.expect(@intFromPtr(w.display) != 0);
    }
}
