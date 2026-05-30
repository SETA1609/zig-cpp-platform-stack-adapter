//! Ladder step 8 — **input contexts** (`pushContext` / `popContext` /
//! `replaceTopContext` / `activeContext` / `isContextActive`). *(v0.7.0)* Needs
//! step 1 (`init`). Pure stack semantics — fully provable in-process. Implement
//! `pushContext` + `activeContext` first; the rest build on them. See
//! `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

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
    platform.pushContext(.gameplay);
    defer _ = platform.popContext();
    try std.testing.expectEqual(platform.InputContextId.gameplay, platform.activeContext());
}

test "pushContext: the last push wins the top" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    platform.pushContext(.ui_menu);
    defer _ = platform.popContext();
    defer _ = platform.popContext();
    try std.testing.expectEqual(platform.InputContextId.ui_menu, platform.activeContext());
}

test "pushContext: pushing makes the context active on the stack" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.dialog);
    defer _ = platform.popContext();
    try std.testing.expect(platform.isContextActive(.dialog));
}

test "popContext: returns the most recently pushed context" {
    try gate(done.pushContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.inventory);
    try std.testing.expectEqual(platform.InputContextId.inventory, platform.popContext());
}

test "popContext: exposes the context beneath it" {
    try gate(done.pushContext and done.popContext and done.activeContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    platform.pushContext(.ui_menu);
    _ = platform.popContext();
    defer _ = platform.popContext();
    try std.testing.expectEqual(platform.InputContextId.gameplay, platform.activeContext());
}

test "popContext: push N then pop N is balanced" {
    try gate(done.pushContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    platform.pushContext(.ui_menu);
    platform.pushContext(.dialog);
    try std.testing.expectEqual(platform.InputContextId.dialog, platform.popContext());
    try std.testing.expectEqual(platform.InputContextId.ui_menu, platform.popContext());
    try std.testing.expectEqual(platform.InputContextId.gameplay, platform.popContext());
}

test "replaceTopContext: swaps the active context in place" {
    try gate(done.pushContext and done.replaceTopContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    defer _ = platform.popContext();
    platform.replaceTopContext(.cinematic);
    try std.testing.expectEqual(platform.InputContextId.cinematic, platform.activeContext());
}

test "replaceTopContext: does not change stack depth" {
    try gate(done.pushContext and done.replaceTopContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    platform.pushContext(.ui_menu);
    platform.replaceTopContext(.dialog);
    try std.testing.expectEqual(platform.InputContextId.dialog, platform.popContext());
    try std.testing.expectEqual(platform.InputContextId.gameplay, platform.popContext());
}

test "replaceTopContext: the replaced context is no longer active" {
    try gate(done.pushContext and done.replaceTopContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.ui_menu);
    defer _ = platform.popContext();
    platform.replaceTopContext(.dialog);
    try std.testing.expect(!platform.isContextActive(.ui_menu));
    try std.testing.expect(platform.isContextActive(.dialog));
}

test "activeContext: reflects the latest push" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.inventory);
    defer _ = platform.popContext();
    try std.testing.expectEqual(platform.InputContextId.inventory, platform.activeContext());
}

test "activeContext: follows a pop back down the stack" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    platform.pushContext(.dialog);
    _ = platform.popContext();
    defer _ = platform.popContext();
    try std.testing.expectEqual(platform.InputContextId.gameplay, platform.activeContext());
}

test "activeContext: follows a replace" {
    try gate(done.pushContext and done.replaceTopContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    defer _ = platform.popContext();
    platform.replaceTopContext(.ui_menu);
    try std.testing.expectEqual(platform.InputContextId.ui_menu, platform.activeContext());
}

test "isContextActive: true for a pushed context" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.dialog);
    defer _ = platform.popContext();
    try std.testing.expect(platform.isContextActive(.dialog));
}

test "isContextActive: false for a context never pushed" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.gameplay);
    defer _ = platform.popContext();
    try std.testing.expect(!platform.isContextActive(.cinematic));
}

test "isContextActive: false after the context is popped" {
    try gate(done.pushContext and done.popContext and done.isContextActive);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(.inventory);
    _ = platform.popContext();
    try std.testing.expect(!platform.isContextActive(.inventory));
}
