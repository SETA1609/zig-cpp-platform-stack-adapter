//! **Contract / data tests** for the `platform` public API — the pure-data
//! surface only: enum numeric values, struct defaults, and type layout. They
//! need no backend, so they **run and must stay green today**; `zig build test`
//! gates merges to `main` on them.
//!
//! Behavioral red→green tests (init / window / events / input / time / …) live
//! in the ordered per-function suite under `src/tests/tdd/`, run on the separate
//! `zig build test-tdd` step, and are skipped until implemented — see
//! `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");

// =============================================================================
// Data / contract tests — active now
// =============================================================================

test "enum values: Renderer" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(platform.Renderer.none));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(platform.Renderer.vulkan));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(platform.Renderer.opengl));
}

test "enum values: MouseButton" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(platform.MouseButton.left));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(platform.MouseButton.right));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(platform.MouseButton.middle));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(platform.MouseButton.x1));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(platform.MouseButton.x2));
}

test "enum values: GamepadButton + GamepadAxis (match enum-values.md)" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(platform.GamepadButton.a));
    try std.testing.expectEqual(@as(u8, 14), @intFromEnum(platform.GamepadButton.dpad_right));
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(platform.GamepadAxis.left_x));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(platform.GamepadAxis.right_trigger));
}

test "enum values: KeyCode anchors (match enum-values.md)" {
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(platform.KeyCode.unknown));
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(platform.KeyCode.a));
    try std.testing.expectEqual(@as(u16, 23), @intFromEnum(platform.KeyCode.w));
    try std.testing.expectEqual(@as(u16, 43), @intFromEnum(platform.KeyCode.escape));
    try std.testing.expectEqual(@as(u16, 83), @intFromEnum(platform.KeyCode.f12));
}

test "extensible enums are non-exhaustive and u16-backed" {
    try std.testing.expectEqual(u16, @typeInfo(platform.ActionId).@"enum".tag_type);
    try std.testing.expectEqual(u16, @typeInfo(platform.InputContextId).@"enum".tag_type);
    try std.testing.expect(!@typeInfo(platform.ActionId).@"enum".is_exhaustive);
    try std.testing.expectEqual(u16, @typeInfo(platform.KeyCode).@"enum".tag_type);
}

test "KeyMods is a single byte and defaults to no modifiers" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(platform.KeyMods));
    const m: platform.KeyMods = .{};
    try std.testing.expect(!m.shift and !m.control and !m.alt and !m.gui);
    try std.testing.expect(!m.caps_lock and !m.num_lock);
}

test "WindowOptions defaults" {
    const o: platform.WindowOptions = .{ .title = "t" };
    try std.testing.expectEqual(@as(u32, 1280), o.size.w);
    try std.testing.expectEqual(@as(u32, 720), o.size.h);
    try std.testing.expectEqual(platform.Renderer.vulkan, o.renderer);
    try std.testing.expect(o.resizable);
    try std.testing.expect(!o.fullscreen and !o.borderless);
    try std.testing.expect(o.position == null);
}

test "InitOptions defaults: video on, rest off" {
    const o: platform.InitOptions = .{};
    try std.testing.expect(o.video);
    try std.testing.expect(!o.gamepad and !o.audio);
}

test "EventFrame defaults to an empty frame" {
    const f: platform.EventFrame = .{};
    try std.testing.expectEqual(@as(usize, 0), f.keys.len);
    try std.testing.expectEqual(@as(usize, 0), f.mouse_motions.len);
    try std.testing.expectEqual(@as(usize, 0), f.resizes.len);
    try std.testing.expect(!f.close_requested);
}

test "version string is present" {
    try std.testing.expect(platform.version.len > 0);
}

test "every public declaration type-checks (incl. unreferenced stubs)" {
    // Forces semantic analysis of every decl/body without calling them, so a
    // signature drift in an otherwise-untested stub is still caught.
    std.testing.refAllDecls(platform);
    std.testing.refAllDecls(platform.Window);
    std.testing.refAllDecls(platform.GlContext);
}
