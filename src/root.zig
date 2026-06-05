//! Public Zig API for the **platform-stack adapter** — renderer-agnostic
//! windowing, input, time, filesystem paths, and per-OS native handles,
//! backed by SDL3.
//!
//! ```zig
//! const platform = @import("platform");
//! ```
//!
//! ## Contract
//!
//! These signatures are the **contract**; the bodies are stubs
//! (`@panic("not implemented")`) until the SDL3 backend under
//! `src/backend/sdl3.zig` fills them in across the v0.6.0 milestone (see
//! `docs/sprint.md`). Calling an unimplemented function compiles and links
//! but traps at runtime with a clear message — so consumers can build and
//! wire against the real surface today.
//!
//! ## Conventions
//!
//!  * Errors use Zig error unions (`!T`); absence uses optionals (`?T`).
//!  * **No backend type (`SDL_*`) ever crosses this surface** (design Rule 1).
//!  * Allocator-taking functions return caller-owned memory — free it.
//!  * Window operations are decls on the `Window` opaque (method syntax).
//!  * `since vX.Y.Z` tags map each item to its milestone (`docs/ROADMAP.md`).

const std = @import("std");

/// Backend-agnostic data types (`Event`, `KeyCode`, `WindowOptions`, …),
/// re-exported below so consumers reach them as `platform.<Type>`.
const common = @import("common.zig");

/// SDL3 backend — the only module that touches SDL. The public functions below
/// delegate to it; no `SDL_*` type crosses back out (design Rule 1).
const backend = @import("backend/sdl3.zig");

// -- Re-exported data types ---------------------------------------------------
// Window geometry & creation
pub const Renderer = common.Renderer;
pub const Size = common.Size;
pub const Position = common.Position;
pub const WindowOptions = common.WindowOptions;
// Events
pub const Event = common.Event;
pub const EventFrame = common.EventFrame;
pub const KeyEvent = common.KeyEvent;
pub const MouseButtonEvent = common.MouseButtonEvent;
pub const MouseMotionEvent = common.MouseMotionEvent;
pub const MouseScrollEvent = common.MouseScrollEvent;
pub const ResizeEvent = common.ResizeEvent;
pub const FocusEvent = common.FocusEvent;
pub const GamepadEvent = common.GamepadEvent;
pub const TextInputEvent = common.TextInputEvent;
pub const FileDropEvent = common.FileDropEvent;
// Input identities
pub const KeyCode = common.KeyCode;
pub const KeyModifiers = common.KeyModifiers;
pub const MouseButton = common.MouseButton;
pub const GamepadButton = common.GamepadButton;
pub const GamepadAxis = common.GamepadAxis;
// Action mapping
pub const ActionId = common.ActionId;
pub const ActionBinding = common.ActionBinding;
pub const GamepadAxisBinding = common.GamepadAxisBinding;
pub const InputContextId = common.InputContextId;
// Capabilities
pub const Capabilities = common.Capabilities;

/// Current API version of this module. Bumps with breaking changes to the
/// public surface; backend swaps bump the MAJOR version.
pub const version = "0.6.0-dev";

// =============================================================================
// Lifecycle
// =============================================================================

/// Which backend subsystems to bring up in `init`. Spin up only what you use.
pub const InitOptions = struct {
    /// Video + windowing + keyboard/mouse input. Required for any window.
    video: bool = true,
    /// Gamepad subsystem (controllers, rumble routing). *(since v0.8.0)*
    gamepad: bool = false,
    /// Audio subsystem. *(since v0.10.0)*
    audio: bool = false,
};

/// Start the backend. Call **once** at startup before any other function.
/// Pairs with `deinit`. *(since v0.6.0)*
pub fn init(opts: InitOptions) !void {
    try backend.init(opts.video, opts.gamepad, opts.audio);
}

/// Shut the backend down and release all global state. Destroy every `Window`
/// first. Safe to call once after a successful `init`. *(since v0.6.0)*
pub fn deinit() void {
    backend.deinit();
}

// =============================================================================
// Window  (since v0.6.0)
// =============================================================================

/// An opaque OS window. Created with `Window.create`, destroyed with
/// `destroy`. The backend handle lives behind the pointer; consumers never
/// see its layout. All operations are safe only between `init` and `deinit`.
pub const Window = opaque {
    /// `*Window` is the opaque public handle for the backend's `WindowState`.
    fn state(self: *Window) *backend.WindowState {
        return @ptrCast(@alignCast(self));
    }

    /// Create and show a window per `opts`. The returned pointer is owned by
    /// the caller — release it with `destroy`. Fails if the backend cannot
    /// satisfy the request (e.g. the chosen `renderer` is unavailable).
    pub fn create(opts: WindowOptions) !*Window {
        const ws = try backend.windowCreate(.{
            .title = opts.title,
            .w = opts.size.w,
            .h = opts.size.h,
            .x = if (opts.position) |p| p.x else null,
            .y = if (opts.position) |p| p.y else null,
            .fullscreen = opts.fullscreen,
            .resizable = opts.resizable,
            .borderless = opts.borderless,
            .vulkan = opts.renderer == .vulkan,
            .opengl = opts.renderer == .opengl,
        });
        return @ptrCast(ws);
    }

    /// Destroy the window and free its backend resources. The pointer is
    /// invalid afterwards.
    pub fn destroy(self: *Window) void {
        backend.windowDestroy(self.state());
    }

    /// Replace the title-bar text (UTF-8). The string is copied.
    pub fn setTitle(self: *Window, title: []const u8) void {
        backend.windowSetTitle(self.state(), title);
    }

    /// Request a new client-area size in pixels.
    pub fn setSize(self: *Window, new_size: Size) void {
        backend.windowSetSize(self.state(), new_size.w, new_size.h);
    }

    /// Request a new window position. Best-effort: ignored where the display
    /// server forbids self-positioning (Wayland — see `capabilities()`).
    pub fn setPosition(self: *Window, new_position: Position) void {
        backend.windowSetPosition(self.state(), new_position.x, new_position.y);
    }

    /// Current drawable size in pixels (DPI-scaled).
    pub fn size(self: *Window) Size {
        return backend.windowSize(self.state());
    }

    /// Current window position in screen coordinates. Best-effort; may be
    /// meaningless where `can_query_window_position` is false.
    pub fn position(self: *Window) Position {
        return backend.windowPosition(self.state());
    }

    /// DPI scale factor: `1.0` = 100%, `2.0` = a typical HiDPI display.
    /// Multiply logical sizes by this to get pixel sizes.
    pub fn scaleFactor(self: *Window) f32 {
        return backend.windowScaleFactor(self.state());
    }

    /// `true` once the window has been asked to close (WM × button, Alt-F4, or
    /// a delivered `.close` event). Drives the main-loop condition; the window
    /// is not actually destroyed until you call `destroy`.
    pub fn shouldClose(self: *Window) bool {
        return backend.windowShouldClose(self.state());
    }

    // -- window state  (since v0.7.0) ----------------------------------------

    /// Enter or leave (borderless) fullscreen on the window's current display.
    /// Best-effort + WM-mediated; query the result with `isFullscreen`.
    pub fn setFullscreen(self: *Window, on: bool) void {
        backend.windowSetFullscreen(self.state(), on);
    }

    /// `true` while the window is in fullscreen.
    pub fn isFullscreen(self: *Window) bool {
        return backend.windowIsFullscreen(self.state());
    }

    /// Allow or forbid the user resizing the window at runtime.
    pub fn setResizable(self: *Window, on: bool) void {
        backend.windowSetResizable(self.state(), on);
    }

    /// `true` while the window is user-resizable.
    pub fn isResizable(self: *Window) bool {
        return backend.windowIsResizable(self.state());
    }

    /// Show or hide the OS title bar and border.
    pub fn setBordered(self: *Window, on: bool) void {
        backend.windowSetBordered(self.state(), on);
    }

    /// `true` while the window has its OS decorations (title bar + border).
    pub fn isBordered(self: *Window) bool {
        return backend.windowIsBordered(self.state());
    }

    /// Clamp the smallest size the user can resize the window to (pixels).
    /// `{0,0}` removes the constraint.
    pub fn setMinSize(self: *Window, new_size: Size) void {
        backend.windowSetMinSize(self.state(), new_size.w, new_size.h);
    }

    /// The current minimum-size constraint (`{0,0}` = none).
    pub fn minSize(self: *Window) Size {
        return backend.windowMinSize(self.state());
    }

    /// Clamp the largest size the user can resize the window to (pixels).
    /// `{0,0}` removes the constraint.
    pub fn setMaxSize(self: *Window, new_size: Size) void {
        backend.windowSetMaxSize(self.state(), new_size.w, new_size.h);
    }

    /// The current maximum-size constraint (`{0,0}` = none).
    pub fn maxSize(self: *Window) Size {
        return backend.windowMaxSize(self.state());
    }

    /// Minimize (iconify) the window. WM-mediated.
    pub fn minimize(self: *Window) void {
        backend.windowMinimize(self.state());
    }

    /// Maximize the window to fill the available work area. WM-mediated.
    pub fn maximize(self: *Window) void {
        backend.windowMaximize(self.state());
    }

    /// Restore the window from minimized/maximized back to its prior size.
    pub fn restore(self: *Window) void {
        backend.windowRestore(self.state());
    }

    /// Raise the window above its siblings and request focus. WM-mediated.
    pub fn raise(self: *Window) void {
        backend.windowRaise(self.state());
    }

    // -- mouse capture  (since v0.7.0) ---------------------------------------

    /// Enter/leave relative mouse mode: the cursor is hidden and locked, and
    /// motion arrives as deltas (`MouseMotionEvent.dx/.dy`) — the mode for
    /// FPS-style camera look. Query with `relativeMouseMode`.
    pub fn setRelativeMouseMode(self: *Window, on: bool) void {
        backend.windowSetRelativeMouseMode(self.state(), on);
    }

    /// `true` while the window is in relative mouse mode.
    pub fn relativeMouseMode(self: *Window) bool {
        return backend.windowRelativeMouseMode(self.state());
    }

    /// Warp the pointer to `(x, y)` in the window's coordinates (pixels).
    pub fn warpMouse(self: *Window, x: f32, y: f32) void {
        backend.windowWarpMouse(self.state(), x, y);
    }

    /// Confine the pointer to this window (a soft grab; distinct from relative
    /// mode). Query with `mouseGrabbed`.
    pub fn setMouseGrab(self: *Window, on: bool) void {
        backend.windowSetMouseGrab(self.state(), on);
    }

    /// `true` while the pointer is grabbed to this window.
    pub fn mouseGrabbed(self: *Window) bool {
        return backend.windowMouseGrabbed(self.state());
    }

    // -- Text input / IME  (since v0.8.0) — stubs until v0.8.0 lands --

    /// Begin IME text composition for this window — `text_input` events start
    /// arriving from the pump. *(since v0.8.0)*
    pub fn startTextInput(self: *Window) void {
        _ = self;
        @panic("not implemented");
    }

    /// Stop IME text composition for this window. *(since v0.8.0)*
    pub fn stopTextInput(self: *Window) void {
        _ = self;
        @panic("not implemented");
    }

    /// `true` while IME text input is active for this window. *(since v0.8.0)*
    pub fn textInputActive(self: *Window) bool {
        _ = self;
        @panic("not implemented");
    }
};

// =============================================================================
// Cursor  (since v0.7.0)
// =============================================================================
// Cursor visibility is a global (process-wide) setting in SDL, not per-window —
// so these are free functions, not `Window` methods.

/// Show the system cursor (the default state).
pub fn showCursor() void {
    backend.showCursor();
}

/// Hide the system cursor. (Relative mouse mode hides it implicitly.)
pub fn hideCursor() void {
    backend.hideCursor();
}

/// `true` while the system cursor is shown.
pub fn cursorVisible() bool {
    return backend.cursorVisible();
}

// =============================================================================
// Events  (since v0.6.0)
// =============================================================================

/// Drive the backend event pump **once per frame**. Translates pending OS
/// events into the library's `Event` representation and refreshes the action
/// and `EventFrame` state. Call this before `nextEvent`, `events`, or any
/// `action*` query each frame. *(since v0.6.0)*
pub fn pollAllEvents() void {
    backend.pollAllEvents();
}

/// Pop the next event from this frame's queue, or `null` when drained. The
/// ergonomic array-of-structs path:
///
/// ```zig
/// platform.pollAllEvents();
/// while (platform.nextEvent()) |ev| switch (ev) {
///     .close => break,
///     .resize => |r| recreateSwapchain(r.w, r.h),
///     else => {},
/// };
/// ```
pub fn nextEvent() ?Event {
    return backend.nextEvent();
}

/// The **struct-of-arrays** view of this frame's events — the data-oriented
/// counterpart to `nextEvent`. Returns per-type slices so you can process
/// events in homogeneous batches with no per-event tag dispatch:
///
/// ```zig
/// platform.pollAllEvents();
/// const frame = platform.events();
/// for (frame.mouse_motions) |m| camera.look(m.dx, m.dy);
/// for (frame.keys) |k| input_table.apply(k);
/// if (frame.close_requested) running = false;
/// ```
///
/// Slices borrow backend storage valid only until the next `pollAllEvents()`.
/// See `EventFrame`. *(since v0.6.0)*
pub fn events() EventFrame {
    return backend.events();
}

// =============================================================================
// Action-mapped input
// =============================================================================
// Prefer actions over raw keys so bindings stay rebindable. v0.6.0 ships key
// bindings + the press queries; contexts, injection, and axis modifiers land
// in v0.7.0.
//
// `action` / `context` parameters are `anytype`: pass values of **your own** enum —
// the library names no actions or contexts (see `ActionId`). They map to the
// backend's 16-bit id space via `toId`.

/// Map any enum value to the backend's action/context id. Compile-errors on a
/// non-enum, so the `anytype` surface still rejects non-enum garbage at the
/// call site rather than silently.
inline fn toId(enum_value: anytype) u16 {
    switch (@typeInfo(@TypeOf(enum_value))) {
        .@"enum" => return @intCast(@intFromEnum(enum_value)),
        else => @compileError("expected an enum value (your own action/context enum), got " ++ @typeName(@TypeOf(enum_value))),
    }
}

/// Bind an input source to an action. Multiple bindings on one action are
/// "any-of". `action` is a value of your own enum. *(since v0.6.0 for keys)*
pub fn bindAction(action: anytype, binding: ActionBinding) void {
    backend.bindAction(toId(action), binding);
}

/// Remove a previously-added binding from an action. *(since v0.6.0)*
pub fn unbindAction(action: anytype, binding: ActionBinding) void {
    backend.unbindAction(toId(action), binding);
}

/// `true` while any binding for the action is held down this frame. *(since v0.6.0)*
pub fn actionPressed(action: anytype) bool {
    return backend.actionPressed(toId(action));
}

/// `true` only on the frame the action transitions released → pressed (edge).
/// Fires once per press, not on key-repeat. *(since v0.6.0)*
pub fn actionJustPressed(action: anytype) bool {
    return backend.actionJustPressed(toId(action));
}

/// `true` only on the frame the action transitions pressed → released (edge).
/// *(since v0.6.0)*
pub fn actionJustReleased(action: anytype) bool {
    return backend.actionJustReleased(toId(action));
}

/// The action's analog value this frame with axis modifiers applied
/// (`[0,1]` for digital/triggers, `[-1,1]` for sticks). *(since v0.7.0)*
pub fn actionValue(action: anytype) f32 {
    return backend.actionValue(toId(action));
}

// -- Stackable input contexts  (since v0.7.0) --------------------------------

/// Push a context onto the input stack; it can shadow lower contexts so the
/// same key means different things in gameplay vs. a menu. *(since v0.7.0)*
pub fn pushContext(context: anytype) void {
    _ = toId(context);
    @panic("not implemented");
}

/// Pop and return the top context as a value of **your** context enum `Ctx`,
/// or `null` if the stack is empty. *(since v0.7.0)*
pub fn popContext(comptime Ctx: type) ?Ctx {
    @panic("not implemented");
}

/// Replace the top context in place (push+pop without churn). *(since v0.7.0)*
pub fn replaceTopContext(context: anytype) void {
    _ = toId(context);
    @panic("not implemented");
}

/// The context currently on top of the stack as a value of your `Ctx` enum,
/// or `null` if no context is active. *(since v0.7.0)*
pub fn activeContext(comptime Ctx: type) ?Ctx {
    @panic("not implemented");
}

/// Whether a given context is anywhere on the active stack. *(since v0.7.0)*
pub fn isContextActive(context: anytype) bool {
    _ = toId(context);
    @panic("not implemented");
}

/// Inject a synthetic action through the **same** downstream path as real
/// input — for scripted sequences, replays, and tests. *(since v0.7.0)*
pub fn injectAction(action: anytype, pressed: bool, value: f32) void {
    backend.injectAction(toId(action), pressed, value);
}

// =============================================================================
// Time  (since v0.6.0)
// =============================================================================

/// Monotonic time in **nanoseconds** since an arbitrary epoch. Use deltas for
/// frame timing; the absolute value is not wall-clock. *(since v0.6.0)*
pub fn now() u64 {
    return backend.now();
}

/// Ticks per second of the high-resolution performance counter. *(since v0.6.0)*
pub fn performanceFrequency() u64 {
    return backend.performanceFrequency();
}

/// Raw high-resolution performance counter value (divide deltas by
/// `performanceFrequency()` for seconds). *(since v0.6.0)*
pub fn performanceCounter() u64 {
    return backend.performanceCounter();
}

/// Block the calling thread for at least `nanoseconds`. *(since v0.6.0)*
pub fn sleep(nanoseconds: u64) void {
    backend.sleep(nanoseconds);
}

// =============================================================================
// Filesystem paths  (since v0.8.0)
// =============================================================================

/// Per-user, per-app directory for **persistent** data (saves, config),
/// created if needed. Caller owns the returned path — free it. *(since v0.8.0)*
pub fn applicationDataDirectory(allocator: std.mem.Allocator, application_name: []const u8) ![]u8 {
    _ = allocator;
    _ = application_name;
    @panic("not implemented");
}

/// Per-user, per-app directory for **disposable** cache data. Caller owns the
/// returned path — free it. *(since v0.8.0)*
pub fn applicationCacheDirectory(allocator: std.mem.Allocator, application_name: []const u8) ![]u8 {
    _ = allocator;
    _ = application_name;
    @panic("not implemented");
}

/// Open a file/URL with the OS default handler (`xdg-open` / `start` /
/// `open`). *(since v0.8.0)*
pub fn openWithSystemDefault(path: []const u8) !void {
    _ = path;
    @panic("not implemented");
}

// =============================================================================
// Renderer hand-off — Vulkan path  (since v0.6.0)
// =============================================================================
// Raw OS primitives only — **no Vulkan types** cross this surface (design
// Rule 2). Feed these into a Vulkan renderer's matching `create*Surface`
// (e.g. the companion vulkan-stack adapter). Each getter returns `null` when
// the active OS / display server is not that one.

/// X11 display + window XID, or `null` if not running under X11.
pub fn getX11Handle(window: *Window) ?struct { display: *anyopaque, window: u64 } {
    const h = backend.windowX11Handle(window.state()) orelse return null;
    return .{ .display = h.display, .window = h.window };
}

/// Wayland display + surface pointers, or `null` if not running under Wayland.
pub fn getWaylandHandle(window: *Window) ?struct { display: *anyopaque, surface: *anyopaque } {
    const h = backend.windowWaylandHandle(window.state()) orelse return null;
    return .{ .display = h.display, .surface = h.surface };
}

/// Win32 HINSTANCE + HWND, or `null` if not on Windows.
pub fn getWin32Handle(window: *Window) ?struct { hinstance: *anyopaque, hwnd: *anyopaque } {
    const h = backend.windowWin32Handle(window.state()) orelse return null;
    return .{ .hinstance = h.hinstance, .hwnd = h.hwnd };
}

/// Android `ANativeWindow*`, or `null` if not on Android.
pub fn getAndroidHandle(window: *Window) ?struct { window: *anyopaque } {
    const h = backend.windowAndroidHandle(window.state()) orelse return null;
    return .{ .window = h.window };
}

/// macOS `CAMetalLayer*`, or `null` if not on macOS. *(deferred — see ROADMAP)*
pub fn getCocoaHandle(window: *Window) ?struct { layer: *anyopaque } {
    _ = window;
    return null; // macOS / Metal layer is deferred — always null for now.
}

/// The Vulkan instance extensions required to present to this window — as
/// NUL-terminated C strings, **no Vulkan types**. Pass straight to
/// `VkInstanceCreateInfo.ppEnabledExtensionNames`. *(since v0.6.0)*
pub fn requiredVulkanInstanceExtensions() []const [*:0]const u8 {
    return backend.vulkanInstanceExtensions();
}

// =============================================================================
// Renderer hand-off — OpenGL path  (since v0.6.0)
// =============================================================================
// A managed GL context. The GL **loader** (glad / a zig-opengl binding) lives
// in consumer code, fed by `glGetProcAddress`; this library ships no GL bindings.

/// An opaque OpenGL context bound to a window.
pub const GlContext = opaque {};

/// Create a GL context for `window` (which must have been created with
/// `renderer = .opengl`). Caller owns it — release with `glDestroyContext`.
pub fn glCreateContext(window: *Window) !*GlContext {
    _ = window;
    @panic("not implemented");
}

/// Make `context` current on `window` for the calling thread.
pub fn glMakeCurrent(window: *Window, context: *GlContext) !void {
    _ = window;
    _ = context;
    @panic("not implemented");
}

/// Present the back buffer (swap buffers) for an OpenGL window.
pub fn glSwapWindow(window: *Window) void {
    _ = window;
    @panic("not implemented");
}

/// Set the swap interval: `0` = off, `1` = vsync, `-1` = adaptive vsync.
pub fn glSetSwapInterval(interval: i32) void {
    _ = interval;
    @panic("not implemented");
}

/// Look up the address of a GL function by name for your loader. Returns
/// `null` if the symbol is unavailable.
pub fn glGetProcAddress(name: [*:0]const u8) ?*const anyopaque {
    _ = name;
    @panic("not implemented");
}

/// Destroy a GL context created by `glCreateContext`.
pub fn glDestroyContext(context: *GlContext) void {
    _ = context;
    @panic("not implemented");
}

// =============================================================================
// Capabilities  (since v0.7.0)
// =============================================================================

/// Query honest per-OS / per-display-server capabilities instead of assuming
/// a feature works everywhere. See `Capabilities`. *(since v0.7.0)*
pub fn capabilities() Capabilities {
    @panic("not implemented");
}

// =============================================================================
// Clipboard  (since v0.8.0)
// =============================================================================

/// The clipboard's UTF-8 text, owned by the caller (`allocator.free` it); an
/// empty string when the clipboard holds no text. *(since v0.8.0)*
pub fn getClipboardText(allocator: std.mem.Allocator) ![]u8 {
    _ = allocator;
    @panic("not implemented");
}

/// Set the clipboard's UTF-8 text. *(since v0.8.0)*
pub fn setClipboardText(text: []const u8) !void {
    _ = text;
    @panic("not implemented");
}

// =============================================================================
// Gamepads  (since v0.8.0)
// =============================================================================
// Connect/disconnect arrive as `gamepad` events from the pump; open a device by
// its instance id to read state, rumble (haptic), and its IMU sensors.

/// The instance ids of the currently-connected gamepads, owned by the caller.
/// *(since v0.8.0)*
pub fn connectedGamepads(allocator: std.mem.Allocator) ![]u32 {
    _ = allocator;
    @panic("not implemented");
}

/// Open a gamepad by instance id (from a `gamepad` connect event or
/// `connectedGamepads`). Caller owns it — release with `close`. *(since v0.8.0)*
pub fn openGamepad(instance_id: u32) !*Gamepad {
    _ = instance_id;
    @panic("not implemented");
}

/// An opened gamepad device. *(since v0.8.0)*
pub const Gamepad = opaque {
    /// Close the device. *(since v0.8.0)*
    pub fn close(self: *Gamepad) void {
        _ = self;
        @panic("not implemented");
    }

    /// The device's display name. *(since v0.8.0)*
    pub fn name(self: *Gamepad) []const u8 {
        _ = self;
        @panic("not implemented");
    }

    /// **Rumble / haptic.** Run the low- and high-frequency motors at `0..=1`
    /// intensities for `duration_ms`. *(since v0.8.0)*
    pub fn rumble(self: *Gamepad, low_frequency: f32, high_frequency: f32, duration_ms: u32) !void {
        _ = self;
        _ = low_frequency;
        _ = high_frequency;
        _ = duration_ms;
        @panic("not implemented");
    }

    /// **Haptic — triggers.** Run the left/right trigger motors (`0..=1`) for
    /// `duration_ms`; not all pads have these. *(since v0.8.0)*
    pub fn rumbleTriggers(self: *Gamepad, left: f32, right: f32, duration_ms: u32) !void {
        _ = self;
        _ = left;
        _ = right;
        _ = duration_ms;
        @panic("not implemented");
    }

    /// **Sensor.** Enable/disable the pad's gyro + accelerometer (off by default
    /// to save power). *(since v0.8.0)*
    pub fn setSensorEnabled(self: *Gamepad, on: bool) !void {
        _ = self;
        _ = on;
        @panic("not implemented");
    }

    /// **Sensor.** Latest gyroscope reading (rad/s; x/y/z). Needs
    /// `setSensorEnabled(true)`. *(since v0.8.0)*
    pub fn gyroscope(self: *Gamepad) [3]f32 {
        _ = self;
        @panic("not implemented");
    }

    /// **Sensor.** Latest accelerometer reading (m/s²; x/y/z). Needs
    /// `setSensorEnabled(true)`. *(since v0.8.0)*
    pub fn accelerometer(self: *Gamepad) [3]f32 {
        _ = self;
        @panic("not implemented");
    }
};

// =============================================================================
// Power  (since v0.8.0)
// =============================================================================

/// System power source / battery state. *(since v0.8.0)*
pub const PowerState = enum { unknown, on_battery, no_battery, charging, charged };

/// A power snapshot. `seconds` / `percent` are `null` when the platform can't
/// report them. *(since v0.8.0)*
pub const PowerInfo = struct {
    state: PowerState,
    seconds: ?u32,
    percent: ?u8,
};

/// Query the current power / battery status. *(since v0.8.0)*
pub fn powerInfo() PowerInfo {
    @panic("not implemented");
}

// =============================================================================
// CPU / software framebuffer  (since v0.9.0)
// =============================================================================
// The `.cpu` renderer path: SDL hands the window a `SDL_Surface` you write
// pixels into on the CPU (no GPU API). For windows created with
// `renderer = .cpu`. Renderer-agnostic — drags in no graphics API.

/// A writable view of a `.cpu` window's backbuffer. `pixels` is `height * pitch`
/// bytes; `pitch` (bytes per row) may exceed `width * 4` for alignment. Pixels
/// are 8-bit BGRA (the SDL window-surface default). *(since v0.9.0)*
pub const PixelBuffer = struct {
    pixels: []u8,
    width: u32,
    height: u32,
    pitch: u32,
};

/// Borrow the `.cpu` window's backbuffer to write pixels into. Valid until the
/// next `presentPixels`; do not retain. *(since v0.9.0)*
pub fn windowPixels(window: *Window) !PixelBuffer {
    _ = window;
    @panic("not implemented");
}

/// Blit the written pixels to the screen (`SDL_UpdateWindowSurface`).
/// *(since v0.9.0)*
pub fn presentPixels(window: *Window) void {
    _ = window;
    @panic("not implemented");
}

// =============================================================================
// Audio  (since v0.10.0)
// =============================================================================
// A minimal `SDL_AudioStream` path: open a device, queue PCM, load WAV — enough
// for sound effects without a separate audio library.

/// PCM sample format. *(since v0.10.0)*
pub const AudioFormat = enum { uint8, int16, int32, float32 };

/// The shape of a PCM stream. *(since v0.10.0)*
pub const AudioSpec = struct {
    frequency: u32 = 48_000,
    channels: u8 = 2,
    format: AudioFormat = .float32,
};

/// Decoded WAV data, owned by the caller (`freeWav`). *(since v0.10.0)*
pub const Wav = struct {
    spec: AudioSpec,
    pcm: []u8,
};

/// Open the default audio device for output with `spec`. Caller owns the stream
/// — release with `destroy`. *(since v0.10.0)*
pub fn openAudioStream(spec: AudioSpec) !*AudioStream {
    _ = spec;
    @panic("not implemented");
}

/// Load a `.wav` file into memory. Free with `freeWav`. *(since v0.10.0)*
pub fn loadWav(allocator: std.mem.Allocator, path: []const u8) !Wav {
    _ = allocator;
    _ = path;
    @panic("not implemented");
}

/// Free WAV data returned by `loadWav`. *(since v0.10.0)*
pub fn freeWav(allocator: std.mem.Allocator, wav: Wav) void {
    _ = allocator;
    _ = wav;
    @panic("not implemented");
}

/// A queued audio output stream. *(since v0.10.0)*
pub const AudioStream = opaque {
    /// Queue PCM bytes for playback (matching the stream's `AudioSpec`).
    /// *(since v0.10.0)*
    pub fn queue(self: *AudioStream, pcm: []const u8) !void {
        _ = self;
        _ = pcm;
        @panic("not implemented");
    }

    /// Bytes still queued (not yet played). *(since v0.10.0)*
    pub fn queued(self: *AudioStream) usize {
        _ = self;
        @panic("not implemented");
    }

    /// Drop all queued audio. *(since v0.10.0)*
    pub fn clear(self: *AudioStream) void {
        _ = self;
        @panic("not implemented");
    }

    /// Close the stream and its device. *(since v0.10.0)*
    pub fn destroy(self: *AudioStream) void {
        _ = self;
        @panic("not implemented");
    }
};
