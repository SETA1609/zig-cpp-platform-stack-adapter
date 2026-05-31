//! Ladder step 8 — **input contexts** (`pushContext` / `popContext` /
//! `replaceTopContext` / `activeContext` / `isContextActive`). *(v0.7.0)* Needs
//! step 1 (`init`). Pure stack semantics — fully provable in-process. Implement
//! `pushContext` + `activeContext` first; the rest build on them. See
//! `CONTRIBUTING.md`.
//!
//! The context vocabulary is the consumer's — the library names none. This test
//! stands in for a game defining its own enum. The returning queries
//! (`popContext`/`activeContext`) take that enum *type* and hand back `?Ctx`
//! (`null` when the stack is empty); after a push they're non-null, so the
//! assertions unwrap with `.?`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const Context = enum(u16) { gameplay, ui_menu, dialog, inventory, cinematic };

const done = .{
    .pushContext = false,
    .popContext = false,
    .replaceTopContext = false,
    .activeContext = false,
    .isContextActive = false,
};

test "pushContext/activeContext: the pushed context becomes active" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.gameplay, platform.activeContext(Context).?);
}

test "pushContext: the last push wins the top" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    platform.pushContext(Context.ui_menu);
    defer _ = platform.popContext(Context);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.ui_menu, platform.activeContext(Context).?);
}

test "pushContext: pushing makes the context active on the stack" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.dialog);
    defer _ = platform.popContext(Context);
    try std.testing.expect(platform.isContextActive(Context.dialog));
}

test "popContext: returns the most recently pushed context" {
    try gate(done.pushContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.inventory);
    try std.testing.expectEqual(Context.inventory, platform.popContext(Context).?);
}

test "popContext: exposes the context beneath it" {
    try gate(done.pushContext and done.popContext and done.activeContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    platform.pushContext(Context.ui_menu);
    _ = platform.popContext(Context);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.gameplay, platform.activeContext(Context).?);
}

test "popContext: push N then pop N is balanced" {
    try gate(done.pushContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    platform.pushContext(Context.ui_menu);
    platform.pushContext(Context.dialog);
    try std.testing.expectEqual(Context.dialog, platform.popContext(Context).?);
    try std.testing.expectEqual(Context.ui_menu, platform.popContext(Context).?);
    try std.testing.expectEqual(Context.gameplay, platform.popContext(Context).?);
}

test "popContext: returns null when the stack is empty" {
    try gate(done.popContext);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.popContext(Context) == null);
}

test "replaceTopContext: swaps the active context in place" {
    try gate(done.pushContext and done.replaceTopContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    platform.replaceTopContext(Context.cinematic);
    try std.testing.expectEqual(Context.cinematic, platform.activeContext(Context).?);
}

test "replaceTopContext: does not change stack depth" {
    try gate(done.pushContext and done.replaceTopContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    platform.pushContext(Context.ui_menu);
    platform.replaceTopContext(Context.dialog);
    try std.testing.expectEqual(Context.dialog, platform.popContext(Context).?);
    try std.testing.expectEqual(Context.gameplay, platform.popContext(Context).?);
}

test "replaceTopContext: the replaced context is no longer active" {
    try gate(done.pushContext and done.replaceTopContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.ui_menu);
    defer _ = platform.popContext(Context);
    platform.replaceTopContext(Context.dialog);
    try std.testing.expect(!platform.isContextActive(Context.ui_menu));
    try std.testing.expect(platform.isContextActive(Context.dialog));
}

test "activeContext: reflects the latest push" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.inventory);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.inventory, platform.activeContext(Context).?);
}

test "activeContext: follows a pop back down the stack" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    platform.pushContext(Context.dialog);
    _ = platform.popContext(Context);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.gameplay, platform.activeContext(Context).?);
}

test "activeContext: null when nothing is active" {
    try gate(done.activeContext);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.activeContext(Context) == null);
}

test "activeContext: follows a replace" {
    try gate(done.pushContext and done.replaceTopContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    platform.replaceTopContext(Context.ui_menu);
    try std.testing.expectEqual(Context.ui_menu, platform.activeContext(Context).?);
}

test "isContextActive: true for a pushed context" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.dialog);
    defer _ = platform.popContext(Context);
    try std.testing.expect(platform.isContextActive(Context.dialog));
}

test "isContextActive: false for a context never pushed" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    try std.testing.expect(!platform.isContextActive(Context.cinematic));
}

test "isContextActive: false after the context is popped" {
    try gate(done.pushContext and done.popContext and done.isContextActive);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.inventory);
    _ = platform.popContext(Context);
    try std.testing.expect(!platform.isContextActive(Context.inventory));
}
