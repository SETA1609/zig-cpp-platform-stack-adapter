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

// WHEN pushing gameplay and querying activeContext · GIVEN a started platform · THEN the active context is gameplay.
test "pushContext/activeContext: the pushed context becomes active" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.gameplay, platform.activeContext(Context).?);
}

// WHEN pushing gameplay then ui_menu · GIVEN a started platform · THEN activeContext is the last-pushed ui_menu.
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

// WHEN pushing dialog and querying isContextActive · GIVEN a started platform · THEN isContextActive(dialog) is true.
test "pushContext: pushing makes the context active on the stack" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.dialog);
    defer _ = platform.popContext(Context);
    try std.testing.expect(platform.isContextActive(Context.dialog));
}

// WHEN popping after pushing inventory · GIVEN a started platform · THEN popContext returns inventory.
test "popContext: returns the most recently pushed context" {
    try gate(done.pushContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.inventory);
    try std.testing.expectEqual(Context.inventory, platform.popContext(Context).?);
}

// WHEN popping ui_menu off a gameplay→ui_menu stack · GIVEN a started platform · THEN activeContext becomes the underlying gameplay.
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

// WHEN pushing gameplay, ui_menu, dialog then popping three times · GIVEN a started platform · THEN pops return dialog, ui_menu, gameplay in LIFO order.
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

// WHEN popping with an empty context stack · GIVEN a started platform · THEN popContext returns null.
test "popContext: returns null when the stack is empty" {
    try gate(done.popContext);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.popContext(Context) == null);
}

// WHEN replaceTopContext swaps gameplay for cinematic · GIVEN a started platform · THEN activeContext becomes cinematic.
test "replaceTopContext: swaps the active context in place" {
    try gate(done.pushContext and done.replaceTopContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    platform.replaceTopContext(Context.cinematic);
    try std.testing.expectEqual(Context.cinematic, platform.activeContext(Context).?);
}

// WHEN replaceTopContext swaps the top of a gameplay→ui_menu stack for dialog · GIVEN a started platform · THEN popping twice yields dialog then gameplay (depth unchanged).
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

// WHEN replaceTopContext swaps ui_menu for dialog · GIVEN a started platform · THEN isContextActive(ui_menu) is false and isContextActive(dialog) is true.
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

// WHEN querying activeContext after pushing inventory · GIVEN a started platform · THEN it reports inventory.
test "activeContext: reflects the latest push" {
    try gate(done.pushContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.inventory);
    defer _ = platform.popContext(Context);
    try std.testing.expectEqual(Context.inventory, platform.activeContext(Context).?);
}

// WHEN popping dialog off a gameplay→dialog stack · GIVEN a started platform · THEN activeContext follows back down to gameplay.
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

// WHEN querying activeContext with an empty stack · GIVEN a started platform · THEN it returns null.
test "activeContext: null when nothing is active" {
    try gate(done.activeContext);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.activeContext(Context) == null);
}

// WHEN replaceTopContext swaps gameplay for ui_menu · GIVEN a started platform · THEN activeContext reports ui_menu.
test "activeContext: follows a replace" {
    try gate(done.pushContext and done.replaceTopContext and done.activeContext and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    platform.replaceTopContext(Context.ui_menu);
    try std.testing.expectEqual(Context.ui_menu, platform.activeContext(Context).?);
}

// WHEN querying isContextActive(dialog) after pushing dialog · GIVEN a started platform · THEN it is true.
test "isContextActive: true for a pushed context" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.dialog);
    defer _ = platform.popContext(Context);
    try std.testing.expect(platform.isContextActive(Context.dialog));
}

// WHEN querying isContextActive(cinematic) after pushing only gameplay · GIVEN a started platform · THEN it is false.
test "isContextActive: false for a context never pushed" {
    try gate(done.pushContext and done.isContextActive and done.popContext);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.gameplay);
    defer _ = platform.popContext(Context);
    try std.testing.expect(!platform.isContextActive(Context.cinematic));
}

// WHEN querying isContextActive(inventory) after pushing then popping inventory · GIVEN a started platform · THEN it is false.
test "isContextActive: false after the context is popped" {
    try gate(done.pushContext and done.popContext and done.isContextActive);
    try h.startup();
    defer platform.deinit();
    platform.pushContext(Context.inventory);
    _ = platform.popContext(Context);
    try std.testing.expect(!platform.isContextActive(Context.inventory));
}
