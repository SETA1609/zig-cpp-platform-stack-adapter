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
pub const KeyMods = common.KeyMods;
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
    /// Create and show a window per `opts`. The returned pointer is owned by
    /// the caller — release it with `destroy`. Fails if the backend cannot
    /// satisfy the request (e.g. the chosen `renderer` is unavailable).
    pub fn create(opts: WindowOptions) !*Window {
        _ = opts;
        @panic("not implemented");
    }

    /// Destroy the window and free its backend resources. The pointer is
    /// invalid afterwards.
    pub fn destroy(self: *Window) void {
        _ = self;
        @panic("not implemented");
    }

    /// Replace the title-bar text (UTF-8). The string is copied.
    pub fn setTitle(self: *Window, title: []const u8) void {
        _ = self;
        _ = title;
        @panic("not implemented");
    }

    /// Request a new client-area size in pixels.
    pub fn setSize(self: *Window, s: Size) void {
        _ = self;
        _ = s;
        @panic("not implemented");
    }

    /// Request a new window position. Best-effort: ignored where the display
    /// server forbids self-positioning (Wayland — see `capabilities()`).
    pub fn setPosition(self: *Window, p: Position) void {
        _ = self;
        _ = p;
        @panic("not implemented");
    }

    /// Current drawable size in pixels (DPI-scaled).
    pub fn size(self: *Window) Size {
        _ = self;
        @panic("not implemented");
    }

    /// Current window position in screen coordinates. Best-effort; may be
    /// meaningless where `can_query_window_position` is false.
    pub fn position(self: *Window) Position {
        _ = self;
        @panic("not implemented");
    }

    /// DPI scale factor: `1.0` = 100%, `2.0` = a typical HiDPI display.
    /// Multiply logical sizes by this to get pixel sizes.
    pub fn scaleFactor(self: *Window) f32 {
        _ = self;
        @panic("not implemented");
    }

    /// `true` once the window has been asked to close (WM × button, Alt-F4, or
    /// a delivered `.close` event). Drives the main-loop condition; the window
    /// is not actually destroyed until you call `destroy`.
    pub fn shouldClose(self: *Window) bool {
        _ = self;
        @panic("not implemented");
    }
};

// =============================================================================
// Events  (since v0.6.0)
// =============================================================================

/// Drive the backend event pump **once per frame**. Translates pending OS
/// events into the library's `Event` representation and refreshes the action
/// and `EventFrame` state. Call this before `nextEvent`, `events`, or any
/// `action*` query each frame. *(since v0.6.0)*
pub fn pollAllEvents() void {
    @panic("not implemented");
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
    @panic("not implemented");
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
    @panic("not implemented");
}

// =============================================================================
// Action-mapped input
// =============================================================================
// Prefer actions over raw keys so bindings stay rebindable. v0.6.0 ships key
// bindings + the press queries; contexts, injection, and axis modifiers land
// in v0.7.0.

/// Bind an input source to an action. Multiple bindings on one action are
/// "any-of". *(since v0.6.0 for keys)*
pub fn bindAction(action: ActionId, binding: ActionBinding) void {
    _ = action;
    _ = binding;
    @panic("not implemented");
}

/// Remove a previously-added binding from an action. *(since v0.6.0)*
pub fn unbindAction(action: ActionId, binding: ActionBinding) void {
    _ = action;
    _ = binding;
    @panic("not implemented");
}

/// `true` while any binding for the action is held down this frame. *(since v0.6.0)*
pub fn actionPressed(action: ActionId) bool {
    _ = action;
    @panic("not implemented");
}

/// `true` only on the frame the action transitions released → pressed (edge).
/// Fires once per press, not on key-repeat. *(since v0.6.0)*
pub fn actionJustPressed(action: ActionId) bool {
    _ = action;
    @panic("not implemented");
}

/// `true` only on the frame the action transitions pressed → released (edge).
/// *(since v0.6.0)*
pub fn actionJustReleased(action: ActionId) bool {
    _ = action;
    @panic("not implemented");
}

/// The action's analog value this frame with axis modifiers applied
/// (`[0,1]` for digital/triggers, `[-1,1]` for sticks). *(since v0.7.0)*
pub fn actionValue(action: ActionId) f32 {
    _ = action;
    @panic("not implemented");
}

// -- Stackable input contexts  (since v0.7.0) --------------------------------

/// Push a context onto the input stack; it can shadow lower contexts so the
/// same key means different things in gameplay vs. a menu. *(since v0.7.0)*
pub fn pushContext(ctx: InputContextId) void {
    _ = ctx;
    @panic("not implemented");
}

/// Pop and return the top context. *(since v0.7.0)*
pub fn popContext() InputContextId {
    @panic("not implemented");
}

/// Replace the top context in place (push+pop without churn). *(since v0.7.0)*
pub fn replaceTopContext(ctx: InputContextId) void {
    _ = ctx;
    @panic("not implemented");
}

/// The context currently on top of the stack. *(since v0.7.0)*
pub fn activeContext() InputContextId {
    @panic("not implemented");
}

/// Whether a given context is anywhere on the active stack. *(since v0.7.0)*
pub fn isContextActive(ctx: InputContextId) bool {
    _ = ctx;
    @panic("not implemented");
}

/// Inject a synthetic action through the **same** downstream path as real
/// input — for scripted sequences, replays, and tests. *(since v0.7.0)*
pub fn injectAction(action: ActionId, pressed: bool, value: f32) void {
    _ = action;
    _ = pressed;
    _ = value;
    @panic("not implemented");
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
pub fn perfFreq() u64 {
    return backend.perfFreq();
}

/// Raw high-resolution performance counter value (divide deltas by
/// `perfFreq()` for seconds). *(since v0.6.0)*
pub fn perfCounter() u64 {
    return backend.perfCounter();
}

/// Block the calling thread for at least `ns` nanoseconds. *(since v0.6.0)*
pub fn sleep(ns: u64) void {
    backend.sleep(ns);
}

// =============================================================================
// Filesystem paths  (since v0.8.0)
// =============================================================================

/// Per-user, per-app directory for **persistent** data (saves, config),
/// created if needed. Caller owns the returned path — free it. *(since v0.8.0)*
pub fn appDataDir(allocator: std.mem.Allocator, app_name: []const u8) ![]u8 {
    _ = allocator;
    _ = app_name;
    @panic("not implemented");
}

/// Per-user, per-app directory for **disposable** cache data. Caller owns the
/// returned path — free it. *(since v0.8.0)*
pub fn appCacheDir(allocator: std.mem.Allocator, app_name: []const u8) ![]u8 {
    _ = allocator;
    _ = app_name;
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
    _ = window;
    @panic("not implemented");
}

/// Wayland display + surface pointers, or `null` if not running under Wayland.
pub fn getWaylandHandle(window: *Window) ?struct { display: *anyopaque, surface: *anyopaque } {
    _ = window;
    @panic("not implemented");
}

/// Win32 HINSTANCE + HWND, or `null` if not on Windows.
pub fn getWin32Handle(window: *Window) ?struct { hinstance: *anyopaque, hwnd: *anyopaque } {
    _ = window;
    @panic("not implemented");
}

/// Android `ANativeWindow*`, or `null` if not on Android.
pub fn getAndroidHandle(window: *Window) ?struct { window: *anyopaque } {
    _ = window;
    @panic("not implemented");
}

/// macOS `CAMetalLayer*`, or `null` if not on macOS. *(deferred — see ROADMAP)*
pub fn getCocoaHandle(window: *Window) ?struct { layer: *anyopaque } {
    _ = window;
    @panic("not implemented");
}

/// The Vulkan instance extensions required to present to this window — as
/// NUL-terminated C strings, **no Vulkan types**. Pass straight to
/// `VkInstanceCreateInfo.ppEnabledExtensionNames`. *(since v0.6.0)*
pub fn requiredVulkanInstanceExtensions() []const [*:0]const u8 {
    @panic("not implemented");
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

/// Make `ctx` current on `window` for the calling thread.
pub fn glMakeCurrent(window: *Window, ctx: *GlContext) !void {
    _ = window;
    _ = ctx;
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
pub fn glDestroyContext(ctx: *GlContext) void {
    _ = ctx;
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
