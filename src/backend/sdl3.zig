//! SDL3 backend for the platform adapter.
//!
//! This is the **only** file that touches SDL — `root.zig` delegates here, and
//! no `SDL_*` type ever crosses back out to the public API (design Rule 1). The
//! C surface is reached through `@cImport`; the SDL3 headers come from the
//! `castholm/SDL` artifact that `build.zig` links into the module.
//!
//! Implemented incrementally along the ladder in `CONTRIBUTING.md`. Filled so
//! far: lifecycle (step 1), time (step 2), window (step 3), events (step 4),
//! action-mapped input (steps 5 & 7).

const std = @import("std");
const common = @import("../common.zig");

/// SDL3's C API. Behind this boundary only — never re-exported.
pub const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

/// libc allocator for backend-owned state (window handles, per-frame event
/// buffers). Distinct from any caller-supplied allocator, and untracked by the
/// test allocator, so it never trips leak detection in the unit tests.
const ally = std.heap.c_allocator;

/// SDL window property under which each window stashes its `*WindowState`, so
/// the event pump can resolve an SDL window id back to our state.
const prop_key = "platform.window_state";

// =============================================================================
// Lifecycle  (ladder step 1)
// =============================================================================

/// Bring up the requested SDL subsystems. Maps the public `InitOptions` to
/// SDL init flags; `SDL_Init` returns `false` on failure.
pub fn init(video: bool, gamepad: bool, audio: bool) !void {
    var flags: c.SDL_InitFlags = 0;
    if (video) flags |= c.SDL_INIT_VIDEO;
    if (gamepad) flags |= c.SDL_INIT_GAMEPAD;
    if (audio) flags |= c.SDL_INIT_AUDIO;
    if (!c.SDL_Init(flags)) return error.BackendInitFailed;
}

/// Tear down all SDL subsystems. Pairs with `init`; safe to re-`init` after.
pub fn deinit() void {
    // Drop all action bindings / injections / state so a fresh `init` starts clean.
    binds.clearRetainingCapacity();
    injects.clearRetainingCapacity();
    states.clearRetainingCapacity();
    c.SDL_Quit();
}

// =============================================================================
// Time  (ladder step 2)
// =============================================================================

/// Monotonic nanoseconds since SDL init.
pub fn now() u64 {
    return c.SDL_GetTicksNS();
}

/// Ticks per second of the high-resolution performance counter.
pub fn perfFreq() u64 {
    return c.SDL_GetPerformanceFrequency();
}

/// Raw high-resolution performance counter value.
pub fn perfCounter() u64 {
    return c.SDL_GetPerformanceCounter();
}

/// Block the calling thread for at least `ns` nanoseconds.
pub fn sleep(ns: u64) void {
    c.SDL_DelayNS(ns);
}

// =============================================================================
// Window  (ladder step 3)
// =============================================================================

/// Backend-side window state. `root.Window` is the opaque public handle; it is
/// just a pointer to one of these (cast back and forth in root.zig).
pub const WindowState = struct {
    sdl: *c.SDL_Window,
    should_close: bool,
};

/// Plain creation inputs mapped from the public `WindowOptions` by root.zig —
/// no public type crosses in, no SDL type crosses out.
pub const WindowCfg = struct {
    title: []const u8,
    w: u32,
    h: u32,
    x: ?i32,
    y: ?i32,
    fullscreen: bool,
    resizable: bool,
    borderless: bool,
    vulkan: bool,
    opengl: bool,
};

pub fn windowCreate(cfg: WindowCfg) !*WindowState {
    var flags: c.SDL_WindowFlags = c.SDL_WINDOW_HIGH_PIXEL_DENSITY;
    if (cfg.vulkan) flags |= c.SDL_WINDOW_VULKAN;
    if (cfg.opengl) flags |= c.SDL_WINDOW_OPENGL;
    if (cfg.resizable) flags |= c.SDL_WINDOW_RESIZABLE;
    if (cfg.borderless) flags |= c.SDL_WINDOW_BORDERLESS;
    if (cfg.fullscreen) flags |= c.SDL_WINDOW_FULLSCREEN;

    const title_z = try ally.dupeZ(u8, cfg.title);
    defer ally.free(title_z);

    const sdl = c.SDL_CreateWindow(title_z.ptr, @intCast(cfg.w), @intCast(cfg.h), flags) orelse
        return error.WindowCreationFailed;

    if (cfg.x) |x| if (cfg.y) |y| {
        _ = c.SDL_SetWindowPosition(sdl, x, y);
    };

    const ws = ally.create(WindowState) catch {
        c.SDL_DestroyWindow(sdl);
        return error.OutOfMemory;
    };
    ws.* = .{ .sdl = sdl, .should_close = false };
    _ = c.SDL_SetPointerProperty(c.SDL_GetWindowProperties(sdl), prop_key, ws);
    return ws;
}

pub fn windowDestroy(ws: *WindowState) void {
    c.SDL_DestroyWindow(ws.sdl);
    ally.destroy(ws);
}

pub fn windowSize(ws: *WindowState) common.Size {
    var w: c_int = 0;
    var h: c_int = 0;
    _ = c.SDL_GetWindowSizeInPixels(ws.sdl, &w, &h);
    return .{ .w = @intCast(w), .h = @intCast(h) };
}

pub fn windowSetSize(ws: *WindowState, w: u32, h: u32) void {
    _ = c.SDL_SetWindowSize(ws.sdl, @intCast(w), @intCast(h));
    // Window resize is async/WM-mediated; block until it's applied so a
    // subsequent `size()` reflects it (best-effort — times out if the WM
    // never honors the request, e.g. a tiling WM).
    _ = c.SDL_SyncWindow(ws.sdl);
}

pub fn windowShouldClose(ws: *WindowState) bool {
    return ws.should_close;
}

pub fn windowScaleFactor(ws: *WindowState) f32 {
    const s = c.SDL_GetWindowDisplayScale(ws.sdl);
    return if (s > 0) s else 1.0;
}

// =============================================================================
// Events  (ladder step 4)
// =============================================================================
// One `pollAllEvents` pumps SDL once, resetting then refilling both views of
// the frame: the struct-of-arrays `EventFrame` (read by `events`) and a flat
// queue (drained by `nextEvent`). Per-frame buffers are retained across frames
// (cleared, not freed) so the SoA slices stay valid until the next pump.

var ev_keys: std.ArrayList(common.KeyEvent) = .empty;
var ev_mouse_buttons: std.ArrayList(common.MouseButtonEvent) = .empty;
var ev_mouse_motions: std.ArrayList(common.MouseMotionEvent) = .empty;
var ev_mouse_scrolls: std.ArrayList(common.MouseScrollEvent) = .empty;
var ev_resizes: std.ArrayList(common.ResizeEvent) = .empty;
var ev_focuses: std.ArrayList(common.FocusEvent) = .empty;
var ev_queue: std.ArrayList(common.Event) = .empty;
var ev_cursor: usize = 0;
var ev_close_requested: bool = false;

pub fn pollAllEvents() void {
    ev_keys.clearRetainingCapacity();
    ev_mouse_buttons.clearRetainingCapacity();
    ev_mouse_motions.clearRetainingCapacity();
    ev_mouse_scrolls.clearRetainingCapacity();
    ev_resizes.clearRetainingCapacity();
    ev_focuses.clearRetainingCapacity();
    ev_queue.clearRetainingCapacity();
    ev_cursor = 0;
    ev_close_requested = false;

    var e: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&e)) translate(&e);

    refreshActions();
}

pub fn nextEvent() ?common.Event {
    if (ev_cursor >= ev_queue.items.len) return null;
    defer ev_cursor += 1;
    return ev_queue.items[ev_cursor];
}

pub fn events() common.EventFrame {
    return .{
        .keys = ev_keys.items,
        .mouse_buttons = ev_mouse_buttons.items,
        .mouse_motions = ev_mouse_motions.items,
        .mouse_scrolls = ev_mouse_scrolls.items,
        .resizes = ev_resizes.items,
        .focuses = ev_focuses.items,
        .close_requested = ev_close_requested,
    };
}

/// Push to both the SoA list (caller does that) and the flat queue. Drops on
/// OOM — losing an event is preferable to crashing the frame loop.
fn enqueue(ev: common.Event) void {
    ev_queue.append(ally, ev) catch {};
}

fn translate(e: *const c.SDL_Event) void {
    switch (e.type) {
        c.SDL_EVENT_QUIT => {
            ev_close_requested = true;
            enqueue(.close);
        },
        c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
            if (c.SDL_GetWindowFromID(e.window.windowID)) |w| {
                const p = c.SDL_GetPointerProperty(c.SDL_GetWindowProperties(w), prop_key, null);
                if (p) |ptr| {
                    const ws: *WindowState = @ptrCast(@alignCast(ptr));
                    ws.should_close = true;
                }
            }
            ev_close_requested = true;
            enqueue(.close);
        },
        c.SDL_EVENT_KEY_DOWN, c.SDL_EVENT_KEY_UP => {
            const ke: common.KeyEvent = .{
                .code = keyFromScancode(e.key.scancode),
                .pressed = e.type == c.SDL_EVENT_KEY_DOWN,
                .repeat = e.key.repeat,
                .mods = modsFrom(e.key.mod),
            };
            ev_keys.append(ally, ke) catch return;
            enqueue(.{ .key = ke });
        },
        c.SDL_EVENT_MOUSE_MOTION => {
            const m: common.MouseMotionEvent = .{ .x = e.motion.x, .y = e.motion.y, .dx = e.motion.xrel, .dy = e.motion.yrel };
            ev_mouse_motions.append(ally, m) catch return;
            enqueue(.{ .mouse_motion = m });
        },
        c.SDL_EVENT_MOUSE_BUTTON_DOWN, c.SDL_EVENT_MOUSE_BUTTON_UP => {
            const b: common.MouseButtonEvent = .{
                .button = mouseButtonFrom(e.button.button),
                .pressed = e.type == c.SDL_EVENT_MOUSE_BUTTON_DOWN,
                .clicks = e.button.clicks,
                .x = e.button.x,
                .y = e.button.y,
            };
            ev_mouse_buttons.append(ally, b) catch return;
            enqueue(.{ .mouse_button = b });
        },
        c.SDL_EVENT_MOUSE_WHEEL => {
            const s: common.MouseScrollEvent = .{ .x = e.wheel.x, .y = e.wheel.y };
            ev_mouse_scrolls.append(ally, s) catch return;
            enqueue(.{ .mouse_scroll = s });
        },
        c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
            const r: common.ResizeEvent = .{ .w = @intCast(e.window.data1), .h = @intCast(e.window.data2) };
            ev_resizes.append(ally, r) catch return;
            enqueue(.{ .resize = r });
        },
        c.SDL_EVENT_WINDOW_FOCUS_GAINED, c.SDL_EVENT_WINDOW_FOCUS_LOST => {
            const f: common.FocusEvent = .{ .focused = e.type == c.SDL_EVENT_WINDOW_FOCUS_GAINED };
            ev_focuses.append(ally, f) catch return;
            enqueue(.{ .focus = f });
        },
        else => {},
    }
}

fn modsFrom(mod: c.SDL_Keymod) common.KeyMods {
    const m: c_int = mod;
    return .{
        .shift = (m & c.SDL_KMOD_SHIFT) != 0,
        .control = (m & c.SDL_KMOD_CTRL) != 0,
        .alt = (m & c.SDL_KMOD_ALT) != 0,
        .gui = (m & c.SDL_KMOD_GUI) != 0,
        .caps_lock = (m & c.SDL_KMOD_CAPS) != 0,
        .num_lock = (m & c.SDL_KMOD_NUM) != 0,
    };
}

fn mouseButtonFrom(b: u8) common.MouseButton {
    return switch (b) {
        c.SDL_BUTTON_LEFT => .left,
        c.SDL_BUTTON_RIGHT => .right,
        c.SDL_BUTTON_MIDDLE => .middle,
        c.SDL_BUTTON_X1 => .x1,
        c.SDL_BUTTON_X2 => .x2,
        else => .left,
    };
}

/// Best-effort scancode → backend-independent `KeyCode`. Letters use the
/// contiguous SDL/`KeyCode` ranges; a handful of common keys are mapped
/// explicitly; everything else is `.unknown`. (Real key delivery is exercised
/// by the manual e2e doc, not the TDD suite, so this can grow over time.)
fn keyFromScancode(sc: c.SDL_Scancode) common.KeyCode {
    const s: c_uint = sc;
    if (s >= c.SDL_SCANCODE_A and s <= c.SDL_SCANCODE_Z) {
        const base: u16 = @intFromEnum(common.KeyCode.a);
        return @enumFromInt(base + @as(u16, @intCast(s - c.SDL_SCANCODE_A)));
    }
    return switch (s) {
        c.SDL_SCANCODE_SPACE => .space,
        c.SDL_SCANCODE_RETURN => .enter,
        c.SDL_SCANCODE_TAB => .tab,
        c.SDL_SCANCODE_BACKSPACE => .backspace,
        c.SDL_SCANCODE_ESCAPE => .escape,
        c.SDL_SCANCODE_LEFT => .left,
        c.SDL_SCANCODE_RIGHT => .right,
        c.SDL_SCANCODE_UP => .up,
        c.SDL_SCANCODE_DOWN => .down,
        else => .unknown,
    };
}

// =============================================================================
// Action-mapped input  (ladder steps 5 & 7)
// =============================================================================
// Bindings map an action to one or more input sources. Each frame, after the
// event pump, every known action's state is recomputed from *live* input
// (SDL keyboard/mouse state) or from a sticky `injectAction` override, and the
// previous frame's pressed-bit is kept for edge queries (just-pressed / -released).

const BindEntry = struct { action: u16, binding: common.ActionBinding };
const InjectEntry = struct { action: u16, pressed: bool, value: f32 };
const ActionState = struct { action: u16, pressed: bool = false, prev: bool = false, value: f32 = 0 };

var binds: std.ArrayList(BindEntry) = .empty;
var injects: std.ArrayList(InjectEntry) = .empty;
var states: std.ArrayList(ActionState) = .empty;

fn statePtr(action: u16) ?*ActionState {
    for (states.items) |*s| if (s.action == action) return s;
    return null;
}

fn ensureState(action: u16) void {
    if (statePtr(action) == null)
        states.append(ally, .{ .action = action }) catch {};
}

fn injectedFor(action: u16) ?InjectEntry {
    for (injects.items) |e| if (e.action == action) return e;
    return null;
}

pub fn bindAction(action: u16, binding: common.ActionBinding) void {
    binds.append(ally, .{ .action = action, .binding = binding }) catch {};
    ensureState(action);
}

pub fn unbindAction(action: u16, binding: common.ActionBinding) void {
    for (binds.items, 0..) |e, i| {
        if (e.action == action and bindingEql(e.binding, binding)) {
            _ = binds.orderedRemove(i);
            return;
        }
    }
}

pub fn injectAction(action: u16, pressed: bool, value: f32) void {
    for (injects.items) |*e| if (e.action == action) {
        e.pressed = pressed;
        e.value = value;
        ensureState(action);
        return;
    };
    injects.append(ally, .{ .action = action, .pressed = pressed, .value = value }) catch {};
    ensureState(action);
}

pub fn actionPressed(action: u16) bool {
    return if (statePtr(action)) |s| s.pressed else false;
}

pub fn actionJustPressed(action: u16) bool {
    return if (statePtr(action)) |s| (s.pressed and !s.prev) else false;
}

pub fn actionJustReleased(action: u16) bool {
    return if (statePtr(action)) |s| (!s.pressed and s.prev) else false;
}

pub fn actionValue(action: u16) f32 {
    return if (statePtr(action)) |s| s.value else 0;
}

/// Recompute every known action's state for this frame. Called by
/// `pollAllEvents` after the SDL event pump (so keyboard/mouse state is fresh).
fn refreshActions() void {
    for (states.items) |*s| {
        s.prev = s.pressed;
        if (injectedFor(s.action)) |inj| {
            s.pressed = inj.pressed;
            s.value = inj.value;
        } else {
            const held = bindingActive(s.action);
            s.pressed = held;
            s.value = if (held) 1.0 else 0.0;
        }
    }
}

fn bindingActive(action: u16) bool {
    for (binds.items) |e| {
        if (e.action == action and bindingHeld(e.binding)) return true;
    }
    return false;
}

fn bindingHeld(b: common.ActionBinding) bool {
    return switch (b) {
        .key => |k| keyHeld(k),
        .mouse_button => |m| mouseHeld(m),
        .composite => |list| blk: {
            for (list) |sub| if (bindingHeld(sub)) break :blk true;
            break :blk false;
        },
        // Gamepad sources land with the v0.8.0 milestone.
        .gamepad_button, .gamepad_axis => false,
    };
}

fn bindingEql(x: common.ActionBinding, y: common.ActionBinding) bool {
    if (std.meta.activeTag(x) != std.meta.activeTag(y)) return false;
    return switch (x) {
        .key => |k| k == y.key,
        .mouse_button => |m| m == y.mouse_button,
        .gamepad_button => |g| g == y.gamepad_button,
        .gamepad_axis => |ax| ax.axis == y.gamepad_axis.axis,
        .composite => |list| list.ptr == y.composite.ptr and list.len == y.composite.len,
    };
}

fn keyHeld(code: common.KeyCode) bool {
    const sc = scancodeFromKey(code);
    if (sc == c.SDL_SCANCODE_UNKNOWN) return false;
    const kb = c.SDL_GetKeyboardState(null);
    return kb[sc];
}

fn mouseHeld(btn: common.MouseButton) bool {
    const num: u32 = switch (btn) {
        .left => 1,
        .middle => 2,
        .right => 3,
        .x1 => 4,
        .x2 => 5,
    };
    const mask = c.SDL_GetMouseState(null, null);
    return (mask & (@as(u32, 1) << @as(u5, @intCast(num - 1)))) != 0;
}

/// Reverse of `keyFromScancode`: our `KeyCode` → SDL scancode, for querying the
/// live keyboard state. Letters use the contiguous range; a handful of common
/// keys are explicit; the rest are `SDL_SCANCODE_UNKNOWN` (never held).
fn scancodeFromKey(code: common.KeyCode) c_uint {
    const v: u16 = @intFromEnum(code);
    const a: u16 = @intFromEnum(common.KeyCode.a);
    const z: u16 = @intFromEnum(common.KeyCode.z);
    if (v >= a and v <= z) {
        const base: c_uint = @intCast(c.SDL_SCANCODE_A);
        return base + @as(c_uint, v - a);
    }
    return switch (code) {
        .space => c.SDL_SCANCODE_SPACE,
        .enter => c.SDL_SCANCODE_RETURN,
        .tab => c.SDL_SCANCODE_TAB,
        .backspace => c.SDL_SCANCODE_BACKSPACE,
        .escape => c.SDL_SCANCODE_ESCAPE,
        .left => c.SDL_SCANCODE_LEFT,
        .right => c.SDL_SCANCODE_RIGHT,
        .up => c.SDL_SCANCODE_UP,
        .down => c.SDL_SCANCODE_DOWN,
        else => c.SDL_SCANCODE_UNKNOWN,
    };
}
