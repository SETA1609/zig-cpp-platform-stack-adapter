# API reference — zig-cpp-platform-stack-adapter

> The **intended public API** of the `platform` module — signatures + semantics, **not** implementation. Use it as a guide; the bodies are yours to fill in and extend. *“since”* tags note the [roadmap](ROADMAP.md) version each lands in.
>
> ```zig
> const platform = @import("platform");
> ```
>
> **Now authored:** this surface lives as code in [`../src/root.zig`](../src/root.zig) (functions) and [`../src/common.zig`](../src/common.zig) (types), with doc-comments matching the descriptions below. Every function is a `@panic("not implemented")` stub until the SDL3 backend lands. Numeric values for the enums (for serialization / rebindable bindings) are in [`enum-values.md`](enum-values.md).

## Conventions

- Errors use Zig error unions (`!T`); absence uses optionals (`?T`).
- **No backend type (`SDL_*`) ever appears in this surface** (design Rule 1).

> **Note for the future — error sets.** The fallible functions currently use
> *inferred* error sets (`!T`). One day, the library-grade move is to pin
> **explicit named error sets** per area (e.g. `InitError!void`,
> `WindowError!*Window`, `PathError![]u8`, `GlError!*GlContext`) — as
> `shaderc.Error` already does in the companion lib — so the error contract is
> documented and a consumer can exhaustively `switch` on it.
> **Counter-argument (why not yet):** defining that taxonomy now means
> *guessing* failure modes before the SDL3 backend exists, and a premature set
> tends to churn. The pragmatic path is to keep sets inferred while the backend
> is built, then **lock explicit named sets at v1.0** once the real failures are
> known. Revisit this at the 1.0 stabilization pass.
- Allocator-taking functions return caller-owned memory — free it.
- Window operations are shown as decls on the `Window` opaque (method syntax). You could equally expose them as module-level free functions taking `*Window` — the signatures are the same either way.

## Lifecycle

```zig
pub const InitOptions = struct {
    video: bool = true,
    gamepad: bool = false,   // since v0.8.0
    audio: bool = false,     // since v0.10.0
};
pub fn init(opts: InitOptions) !void;   // start the backend; call once at startup
pub fn deinit() void;                    // shut the backend down
```

## Window  *(since v0.6.0)*

```zig
pub const Renderer = enum { none, vulkan, opengl };   // GPU API bound at creation
pub const Size = struct { w: u32, h: u32 };
pub const Position = struct { x: i32, y: i32 };

pub const WindowOptions = struct {
    title: []const u8,
    size: Size = .{ .w = 1280, .h = 720 },
    position: ?Position = null,      // null → OS default
    fullscreen: bool = false,
    resizable: bool = true,
    borderless: bool = false,
    renderer: Renderer = .vulkan,
    parent: ?*Window = null,         // modal / child windows
};

pub const Window = opaque {
    pub fn create(opts: WindowOptions) !*Window;
    pub fn destroy(self: *Window) void;
    pub fn setTitle(self: *Window, title: []const u8) void;
    pub fn setSize(self: *Window, s: Size) void;
    pub fn setPosition(self: *Window, p: Position) void;   // best-effort (Wayland: advisory)
    pub fn size(self: *Window) Size;
    pub fn position(self: *Window) Position;               // best-effort
    pub fn scaleFactor(self: *Window) f32;                 // 1.0 = 100% DPI
    pub fn shouldClose(self: *Window) bool;

    // window state (since v0.7.0) — setters are best-effort/WM-mediated;
    // the resizable/bordered flags and min/max size are tracked by SDL.
    pub fn setFullscreen(self: *Window, on: bool) void;
    pub fn isFullscreen(self: *Window) bool;
    pub fn setResizable(self: *Window, on: bool) void;
    pub fn isResizable(self: *Window) bool;
    pub fn setBordered(self: *Window, on: bool) void;
    pub fn isBordered(self: *Window) bool;
    pub fn setMinSize(self: *Window, s: Size) void;        // {0,0} = no constraint
    pub fn minSize(self: *Window) Size;
    pub fn setMaxSize(self: *Window, s: Size) void;        // {0,0} = no constraint
    pub fn maxSize(self: *Window) Size;
    pub fn minimize(self: *Window) void;
    pub fn maximize(self: *Window) void;
    pub fn restore(self: *Window) void;
    pub fn raise(self: *Window) void;

    // mouse capture (since v0.7.0) — relative mode delivers motion as deltas
    // (MouseMotionEvent.dx/.dy) for FPS-style look.
    pub fn setRelativeMouseMode(self: *Window, on: bool) void;
    pub fn relativeMouseMode(self: *Window) bool;
    pub fn warpMouse(self: *Window, x: f32, y: f32) void;  // window coords (pixels)
    pub fn setMouseGrab(self: *Window, on: bool) void;     // confine pointer to window
    pub fn mouseGrabbed(self: *Window) bool;
};
```

## Cursor  *(since v0.7.0)*

Global (process-wide) cursor visibility — free functions, not `Window` methods.

```zig
pub fn showCursor() void;
pub fn hideCursor() void;        // relative mouse mode hides it implicitly
pub fn cursorVisible() bool;
```

## Events  *(since v0.6.0)*

```zig
pub const Event = union(enum) {
    key:          KeyEvent,
    mouse_button: MouseButtonEvent,
    mouse_motion: MouseMotionEvent,
    mouse_scroll: MouseScrollEvent,
    resize:       ResizeEvent,
    focus:        FocusEvent,
    close,                          // window-close requested
    gamepad:      GamepadEvent,     // since v0.8.0
    text_input:   TextInputEvent,   // IME-composed text; since v0.8.0
    file_drop:    FileDropEvent,
};

pub fn pollAllEvents() void;        // drive the backend pump once per frame

// Two ways to consume the frame's events — pick one per frame:
pub fn nextEvent() ?Event;          // (1) AoS: drain the queue; null when empty
pub fn events() EventFrame;         // (2) SoA: per-type slices for batch processing

// Payloads are plain structs, e.g.:
pub const KeyEvent = struct { code: KeyCode, pressed: bool, repeat: bool, mods: KeyMods };
pub const MouseMotionEvent = struct { x: f32, y: f32, dx: f32, dy: f32 };
pub const ResizeEvent = struct { w: u32, h: u32 };
// MouseButton/Scroll/Focus/Gamepad/TextInput/FileDrop events follow the same pattern.
```

`nextEvent` is the ergonomic array-of-structs path. `events` is its data-oriented counterpart — a struct-of-arrays view of the *same* captured frame, grouped by type so you can process events in homogeneous batches with no per-event tag dispatch:

```zig
pub const EventFrame = struct {
    keys:           []const KeyEvent,
    mouse_buttons:  []const MouseButtonEvent,
    mouse_motions:  []const MouseMotionEvent,
    mouse_scrolls:  []const MouseScrollEvent,
    resizes:        []const ResizeEvent,
    focuses:        []const FocusEvent,
    close_requested: bool,            // payload-less → a flag, not a slice
    gamepads:       []const GamepadEvent,    // since v0.8.0
    text_inputs:    []const TextInputEvent,  // since v0.8.0
    file_drops:     []const FileDropEvent,   // since v0.8.0
};
```

Every slice borrows backend storage valid only until the next `pollAllEvents()` — copy out anything you keep. The two views see the same events; `nextEvent` consumes the queue while `events` is non-consuming, so use one style per frame to avoid double-handling.

## Action-mapped input

Prefer actions over raw keys so bindings stay rebindable.

```zig
// --- bindings (keys since v0.6.0; full set v0.7.0) ---
pub const ActionId = enum { move_forward, move_back, jump, interact, menu_pause, _ };  // non-exhaustive: extend freely
pub const ActionBinding = union(enum) {
    key:            KeyCode,
    mouse_button:   MouseButton,
    gamepad_button: GamepadButton,                   // since v0.8.0
    gamepad_axis:   struct {
        axis: GamepadAxis,
        threshold: f32 = 0.15,   // deadzone
        smooth: f32 = 0.0,       // EMA smoothing; 0 = off
        scale: f32 = 1.0,
        invert: bool = false,
    },
    composite:      []const ActionBinding,           // any-of
};

pub fn bindAction(action: ActionId, binding: ActionBinding) void;
pub fn unbindAction(action: ActionId, binding: ActionBinding) void;
pub fn actionPressed(action: ActionId) bool;
pub fn actionJustPressed(action: ActionId) bool;
pub fn actionJustReleased(action: ActionId) bool;
pub fn actionValue(action: ActionId) f32;            // analog; modifiers applied

// --- stackable input contexts (since v0.7.0) ---
pub const InputContextId = enum { gameplay, ui_menu, dialog, inventory, cinematic, _ };
pub fn pushContext(ctx: InputContextId) void;
pub fn popContext() InputContextId;
pub fn replaceTopContext(ctx: InputContextId) void;
pub fn activeContext() InputContextId;
pub fn isContextActive(ctx: InputContextId) bool;

// --- synthetic injection: same downstream path as real input (since v0.7.0) ---
pub fn injectAction(action: ActionId, pressed: bool, value: f32) void;
```

## Time  *(since v0.6.0)*

```zig
pub fn now() u64;          // monotonic nanoseconds
pub fn perfFreq() u64;     // ticks per second
pub fn perfCounter() u64;  // raw perf counter
pub fn sleep(ns: u64) void;
```

## Filesystem paths  *(since v0.8.0)*

```zig
pub fn appDataDir(allocator: std.mem.Allocator, app_name: []const u8) ![]u8;   // caller frees
pub fn appCacheDir(allocator: std.mem.Allocator, app_name: []const u8) ![]u8;  // caller frees
pub fn openWithSystemDefault(path: []const u8) !void;                          // xdg-open / start / open
```

## Renderer hand-off — Vulkan path  *(since v0.6.0)*

Raw OS primitives only — **no Vulkan types**. Feed these to a Vulkan renderer's matching `create*Surface` (e.g. the companion [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)).

```zig
pub fn getX11Handle(window: *Window) ?struct { display: *anyopaque, window: u64 };
pub fn getWaylandHandle(window: *Window) ?struct { display: *anyopaque, surface: *anyopaque };
pub fn getWin32Handle(window: *Window) ?struct { hinstance: *anyopaque, hwnd: *anyopaque };
pub fn getAndroidHandle(window: *Window) ?struct { window: *anyopaque };
pub fn getCocoaHandle(window: *Window) ?struct { layer: *anyopaque };   // deferred
pub fn requiredVulkanInstanceExtensions() []const [*:0]const u8;        // C strings; no Vulkan types
```

Each getter returns `null` when the active OS / display server isn't that one.

## Renderer hand-off — OpenGL path  *(since v0.6.0)*

Managed GL context. The GL **loader** (glad / a zig-opengl binding) lives in your code, fed by `glGetProcAddress` — this library ships no GL bindings.

```zig
pub const GlContext = opaque {};
pub fn glCreateContext(window: *Window) !*GlContext;
pub fn glMakeCurrent(window: *Window, ctx: *GlContext) !void;
pub fn glSwapWindow(window: *Window) void;
pub fn glSetSwapInterval(interval: i32) void;                  // 0 off · 1 vsync · -1 adaptive
pub fn glGetProcAddress(name: [*:0]const u8) ?*const anyopaque;
pub fn glDestroyContext(ctx: *GlContext) void;
```

## Capabilities  *(since v0.7.0)*

Honest per-OS divergence — query instead of assuming.

```zig
pub const Capabilities = struct {
    can_set_window_position: bool,    // false on Wayland
    can_query_window_position: bool,
    can_capture_global_input: bool,
    high_dpi_scale_per_monitor: bool,
    // ...
};
pub fn capabilities() Capabilities;
```

## Minimal usage

```zig
const platform = @import("platform");

try platform.init(.{});
defer platform.deinit();

const win = try platform.Window.create(.{ .title = "demo", .renderer = .vulkan });
defer win.destroy();

platform.bindAction(.menu_pause, .{ .key = .escape });
while (!win.shouldClose()) {
    platform.pollAllEvents();
    while (platform.nextEvent()) |ev| switch (ev) {
        .resize => |r| { _ = r; /* recreate swapchain */ },
        else => {},
    };
    if (platform.actionJustPressed(.menu_pause)) break;
    // render with your GPU API of choice ...
}
```

---

These signatures are the **contract**, not the implementation. Start with the v0.6.0 set; the rest are slots to fill as you need them. Expand freely — keep the four [design rules](ROADMAP.md#design-rules-non-negotiable) intact so a backend swap stays cheap.
