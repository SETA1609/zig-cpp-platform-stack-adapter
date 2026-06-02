//! Shared, backend-agnostic types for the `platform` public API.
//!
//! Everything here is **pure data** — plain structs, enums, and tagged
//! unions that describe windows, events, and input in terms the *consumer*
//! cares about, never in terms of the backend. No `SDL_*` type ever appears
//! in this file (design Rule 1): a backend swap (SDL3 → native) must not
//! ripple into a single declaration here.
//!
//! `root.zig` re-exports these so consumers reach them as `platform.Event`,
//! `platform.KeyCode`, etc. — they are split out only to keep the API
//! surface (the functions) readable. The `since vX.Y.Z` tags map each type
//! to the milestone it lands in; see `docs/ROADMAP.md`.

// =============================================================================
// Window geometry & creation
// =============================================================================

/// Which GPU API a window is bound to **at creation time**.
///
/// A window binds to exactly one renderer for its whole lifetime — this is a
/// switch, not a mix (you cannot drive Vulkan and OpenGL into the same
/// window). The choice decides which hand-off surface the library exposes:
///
///  * `.vulkan` — per-OS native handle getters + `requiredVulkanInstanceExtensions()`.
///  * `.opengl` — a managed GL context (`glCreateContext`/`glSwapWindow`/…).
///  * `.none`   — window + events only; no GPU API touched (headless tools,
///                custom 2D, and the platform-only decoupling check).
pub const Renderer = enum {
    /// No GPU API. The window pumps events but exposes no rendering surface.
    none,
    /// Vulkan: the library hands back raw OS primitives for surface creation.
    vulkan,
    /// OpenGL: the library manages the GL context; the GL loader lives in
    /// consumer code, fed by `glGetProcAddress`.
    opengl,
};

/// A window/framebuffer size in **pixels**. Unsigned: a window is never
/// negatively sized.
pub const Size = struct {
    /// Width in pixels.
    w: u32,
    /// Height in pixels.
    h: u32,
};

/// A window position in **screen coordinates**, top-left origin. Signed
/// because a window may legitimately sit at negative coordinates on a
/// multi-monitor desktop (a monitor to the left of the primary).
pub const Position = struct {
    /// X offset from the desktop origin.
    x: i32,
    /// Y offset from the desktop origin.
    y: i32,
};

/// Everything needed to create a `Window`. Defaults give a sensible
/// resizable 1280×720 Vulkan window centred by the OS.
pub const WindowOptions = struct {
    /// Title bar text (UTF-8). Borrowed only for the duration of the
    /// `create` call — the backend copies it.
    title: []const u8,
    /// Initial client-area size in pixels.
    size: Size = .{ .w = 1280, .h = 720 },
    /// Initial position, or `null` to let the OS choose (usually centred).
    position: ?Position = null,
    /// Start in (borderless) fullscreen on the current display.
    fullscreen: bool = false,
    /// Allow the user to resize the window.
    resizable: bool = true,
    /// Drop the OS title bar and border (client-decorated window).
    borderless: bool = false,
    /// Which GPU API to bind. See `Renderer`.
    renderer: Renderer = .vulkan,
    /// Parent window for modal/child windows, or `null` for a top-level
    /// window. (Multi-window is deferred past v1.0; treat as `null` today.)
    parent: ?*anyopaque = null,
};

// =============================================================================
// Events  (since v0.6.0)
// =============================================================================

/// A single input or window event, drained one at a time from the queue via
/// `nextEvent()`. The active variant tells you which payload struct is valid.
///
/// Variants without a payload (`.close`) carry no data — their mere arrival
/// is the signal.
pub const Event = union(enum) {
    /// A key was pressed or released. See `KeyEvent`.
    key: KeyEvent,
    /// A mouse button changed state. See `MouseButtonEvent`.
    mouse_button: MouseButtonEvent,
    /// The pointer moved. See `MouseMotionEvent`.
    mouse_motion: MouseMotionEvent,
    /// The scroll wheel / trackpad scrolled. See `MouseScrollEvent`.
    mouse_scroll: MouseScrollEvent,
    /// The window's drawable size changed — recreate the swapchain. See `ResizeEvent`.
    resize: ResizeEvent,
    /// The window gained or lost keyboard focus. See `FocusEvent`.
    focus: FocusEvent,
    /// The user requested the window be closed (WM × button / Alt-F4). The
    /// window is **not** destroyed yet — that is the consumer's call.
    close,
    /// A gamepad button/axis changed. See `GamepadEvent`. *(since v0.8.0)*
    gamepad: GamepadEvent,
    /// IME-composed text was committed. See `TextInputEvent`. *(since v0.8.0)*
    text_input: TextInputEvent,
    /// One or more files were dropped onto the window. See `FileDropEvent`. *(since v0.8.0)*
    file_drop: FileDropEvent,
};

/// Payload for `Event.key`.
pub const KeyEvent = struct {
    /// The backend-independent key identity (physical-key based; see `KeyCode`).
    code: KeyCode,
    /// `true` on press, `false` on release.
    pressed: bool,
    /// `true` if this is an auto-repeat while the key is held (OS key-repeat).
    repeat: bool,
    /// Modifier keys held at the time of this event.
    modifiers: KeyModifiers,
};

/// Payload for `Event.mouse_button`.
pub const MouseButtonEvent = struct {
    /// Which button changed.
    button: MouseButton,
    /// `true` on press, `false` on release.
    pressed: bool,
    /// Click count (1 = single, 2 = double, …) for rapid repeated clicks.
    clicks: u8,
    /// Pointer X in window coordinates at the moment of the event.
    x: f32,
    /// Pointer Y in window coordinates at the moment of the event.
    y: f32,
};

/// Payload for `Event.mouse_motion`. Carries both absolute position and the
/// relative delta since the previous motion event (useful for camera look).
pub const MouseMotionEvent = struct {
    /// Absolute X in window coordinates.
    x: f32,
    /// Absolute Y in window coordinates.
    y: f32,
    /// X movement since the previous motion event.
    dx: f32,
    /// Y movement since the previous motion event.
    dy: f32,
};

/// Payload for `Event.mouse_scroll`. Values are in "lines"/notches; sign
/// follows the natural axis (positive `y` = scroll up / away from the user).
pub const MouseScrollEvent = struct {
    /// Horizontal scroll amount.
    x: f32,
    /// Vertical scroll amount.
    y: f32,
};

/// Payload for `Event.resize`. The new **drawable** size in pixels (already
/// DPI-scaled), i.e. the size your swapchain/framebuffer should match.
pub const ResizeEvent = struct {
    /// New drawable width in pixels.
    w: u32,
    /// New drawable height in pixels.
    h: u32,
};

/// Payload for `Event.focus`.
pub const FocusEvent = struct {
    /// `true` if the window just gained keyboard focus, `false` if it lost it.
    focused: bool,
};

/// Payload for `Event.gamepad`. *(since v0.8.0)*
pub const GamepadEvent = struct {
    /// Index of the gamepad that produced the event (0 = first connected).
    gamepad_id: u32,
    /// What changed on the device.
    kind: union(enum) {
        /// A digital button transitioned. `bool` is the new pressed state.
        button: struct { button: GamepadButton, pressed: bool },
        /// An analog axis moved. `value` is normalised to `[-1, 1]` (triggers `[0, 1]`).
        axis: struct { axis: GamepadAxis, value: f32 },
        /// The device was plugged in.
        connected,
        /// The device was unplugged.
        disconnected,
    },
};

/// Payload for `Event.text_input` — IME-composed, ready-to-insert text.
/// Distinct from `KeyEvent`: this is *characters*, not *keys*. *(since v0.8.0)*
pub const TextInputEvent = struct {
    /// The committed UTF-8 text. Borrowed for the lifetime of this event
    /// only — copy it if you need to keep it.
    text: []const u8,
};

/// Payload for `Event.file_drop`. *(since v0.8.0)*
pub const FileDropEvent = struct {
    /// Absolute path of the dropped file (UTF-8). Borrowed for the lifetime
    /// of this event only — copy it if you need to keep it. Multi-file drops
    /// arrive as one event per path.
    path: []const u8,
    /// Drop X in window coordinates.
    x: f32,
    /// Drop Y in window coordinates.
    y: f32,
};

/// A **struct-of-arrays** view of every event captured by one `pollAllEvents()`
/// call, grouped by type — the data-oriented counterpart to draining the
/// tagged-union queue with `nextEvent()`.
///
/// Use this when you want to process events in homogeneous batches with no
/// per-event tag dispatch (e.g. feed `mouse_motions` straight into a camera
/// integrator, or fold `keys` into an input state table). Each slice holds
/// only the events of that type, in arrival order.
///
/// **Lifetime:** every slice borrows backend-owned, per-frame storage and is
/// valid only until the next `pollAllEvents()` — copy out anything you keep.
/// The same frame can be read either way: the SoA view and `nextEvent()` see
/// the same captured events; the SoA accessor is non-consuming and idempotent,
/// while `nextEvent()` pops from the queue. Pick one style per frame to avoid
/// double-handling.
pub const EventFrame = struct {
    /// All key presses/releases this frame, in order.
    keys: []const KeyEvent = &.{},
    /// All mouse-button changes this frame.
    mouse_buttons: []const MouseButtonEvent = &.{},
    /// All pointer-motion samples this frame.
    mouse_motions: []const MouseMotionEvent = &.{},
    /// All scroll samples this frame.
    mouse_scrolls: []const MouseScrollEvent = &.{},
    /// All drawable-size changes this frame (usually 0 or 1; coalesce to the last).
    resizes: []const ResizeEvent = &.{},
    /// All focus gain/loss transitions this frame.
    focuses: []const FocusEvent = &.{},
    /// Whether a window-close was requested this frame. Payload-less, so it
    /// collapses to a single flag rather than a slice.
    close_requested: bool = false,
    /// All gamepad button/axis/connection events this frame. *(since v0.8.0)*
    gamepads: []const GamepadEvent = &.{},
    /// All committed text-input events this frame. *(since v0.8.0)*
    text_inputs: []const TextInputEvent = &.{},
    /// All file-drop events this frame. *(since v0.8.0)*
    file_drops: []const FileDropEvent = &.{},
};

// =============================================================================
// Keyboard
// =============================================================================

/// A backend-independent key identity.
///
/// Keys are identified by their **physical position** (US-QWERTY layout
/// reference), not the character they produce under the active keyboard
/// layout — so `.w`/`.a`/`.s`/`.d` are the WASD cluster on every layout. For
/// *text* (layout-aware, IME-composed characters) use `Event.text_input`
/// instead.
///
/// Non-exhaustive (`_`): the list covers the common desktop keys; extend it
/// as backends expose more without it being a breaking change.
pub const KeyCode = enum(u16) {
    unknown,

    // Letters
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    // Number row
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",

    // Whitespace & editing
    space,
    enter,
    tab,
    backspace,
    delete,
    insert,
    escape,

    // Navigation
    left,
    right,
    up,
    down,
    home,
    end,
    page_up,
    page_down,

    // Modifiers
    left_shift,
    right_shift,
    left_control,
    right_control,
    left_alt,
    right_alt,
    /// "Super" / Windows / Command key (left).
    left_gui,
    /// "Super" / Windows / Command key (right).
    right_gui,
    caps_lock,

    // Punctuation (US-QWERTY positions)
    minus,
    equals,
    left_bracket,
    right_bracket,
    backslash,
    semicolon,
    apostrophe,
    grave,
    comma,
    period,
    slash,

    // Function row
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,

    _,
};

/// Modifier keys held during a `KeyEvent`. A packed bitfield so it copies as
/// a single byte; default-constructs to "no modifiers".
pub const KeyModifiers = packed struct {
    /// Either Shift key is down.
    shift: bool = false,
    /// Either Control key is down.
    control: bool = false,
    /// Either Alt / Option key is down.
    alt: bool = false,
    /// Either GUI key (Windows / Command / Super) is down.
    gui: bool = false,
    /// Caps Lock is currently *active* (toggled on), not merely pressed.
    caps_lock: bool = false,
    /// Num Lock is currently active.
    num_lock: bool = false,
    /// Reserved; keeps the struct a whole byte. Always 0.
    _pad: u2 = 0,
};

// =============================================================================
// Mouse
// =============================================================================

/// A mouse button. `x1`/`x2` are the "back"/"forward" thumb buttons.
pub const MouseButton = enum {
    left,
    right,
    middle,
    /// Extra button 1 (typically "back").
    x1,
    /// Extra button 2 (typically "forward").
    x2,
};

// =============================================================================
// Gamepad  (since v0.8.0)
// =============================================================================

/// A gamepad button, named by the standard (Xbox-style) layout. Other pad
/// families are mapped onto these canonical names by the backend.
pub const GamepadButton = enum {
    a,
    b,
    x,
    y,
    /// Left shoulder bumper (LB).
    left_bumper,
    /// Right shoulder bumper (RB).
    right_bumper,
    back,
    start,
    guide,
    /// Pressing in the left analog stick (L3).
    left_stick,
    /// Pressing in the right analog stick (R3).
    right_stick,
    dpad_up,
    dpad_down,
    dpad_left,
    dpad_right,
};

/// A gamepad analog axis. Sticks report `[-1, 1]` per axis; triggers report
/// `[0, 1]`.
pub const GamepadAxis = enum {
    /// Left stick horizontal (−1 left … +1 right).
    left_x,
    /// Left stick vertical (−1 up … +1 down).
    left_y,
    /// Right stick horizontal.
    right_x,
    /// Right stick vertical.
    right_y,
    /// Left trigger (LT), 0 released … 1 fully pressed.
    left_trigger,
    /// Right trigger (RT).
    right_trigger,
};

// =============================================================================
// Action-mapped input
// =============================================================================

/// A game-meaningful action that input is mapped *to*, so bindings stay
/// rebindable and raw key codes never leak into game logic.
///
/// **The library defines no actions of its own** — the action vocabulary is
/// your game's policy, not the platform layer's. Define your own enum and pass
/// its values straight to `bindAction` / `actionPressed` / `injectAction` / …,
/// which accept *any* enum:
///
/// ```zig
/// const Action = enum(u16) { move_forward, jump, interact, menu_pause };
/// platform.bindAction(Action.menu_pause, .{ .key = .escape });
/// if (platform.actionJustPressed(Action.menu_pause)) pause();
/// ```
///
/// This opaque, non-exhaustive type names only the underlying id space (a
/// 16-bit id); it carries no variants. Contrast `KeyCode` / `GamepadButton`,
/// which *are* the library's domain — physical inputs are universal, actions
/// are not.
pub const ActionId = enum(u16) { _ };

/// One way to trigger an `ActionId`. Bind several to the same action for
/// "any-of" behaviour (e.g. W *or* up-arrow), or nest them with `.composite`.
pub const ActionBinding = union(enum) {
    /// Triggered by a keyboard key.
    key: KeyCode,
    /// Triggered by a mouse button.
    mouse_button: MouseButton,
    /// Triggered by a gamepad button. *(since v0.8.0)*
    gamepad_button: GamepadButton,
    /// Triggered by a gamepad axis crossing a threshold, with optional
    /// shaping applied to the analog value. *(since v0.8.0)*
    gamepad_axis: GamepadAxisBinding,
    /// Any-of: the action fires if **any** nested binding fires. The slice is
    /// borrowed; it must outlive the binding.
    composite: []const ActionBinding,
};

/// Shaping parameters for a `.gamepad_axis` binding. Applied in order:
/// deadzone → invert → scale → smoothing.
pub const GamepadAxisBinding = struct {
    /// Which axis drives the action.
    axis: GamepadAxis,
    /// Deadzone: input magnitudes below this are clamped to 0.
    threshold: f32 = 0.15,
    /// Exponential-moving-average smoothing factor; `0` disables smoothing.
    smooth: f32 = 0.0,
    /// Linear multiplier applied to the (deadzoned) value.
    scale: f32 = 1.0,
    /// Negate the axis (e.g. to flip stick-Y).
    invert: bool = false,
};

/// A stackable input context. Pushing a context can shadow lower ones so the
/// same physical key means different things in gameplay vs. a menu. *(since v0.7.0)*
///
/// **The library defines no contexts of its own** — like `ActionId`, the
/// context vocabulary is yours. Define your own enum and pass it to
/// `pushContext` / `isContextActive` / …; the returning queries
/// (`popContext` / `activeContext`) take your enum *type* and hand it back:
///
/// ```zig
/// const Context = enum(u16) { gameplay, ui_menu, dialog };
/// platform.pushContext(Context.ui_menu);
/// const top = platform.activeContext(Context); // -> Context
/// ```
///
/// Opaque and non-exhaustive; carries no variants.
pub const InputContextId = enum(u16) { _ };

// =============================================================================
// Capabilities  (since v0.7.0)
// =============================================================================

/// Honest per-OS / per-display-server divergence. Query these instead of
/// assuming a feature works everywhere — e.g. Wayland forbids a client from
/// positioning its own window, so `can_set_window_position` is `false` there.
pub const Capabilities = struct {
    /// Whether `Window.setPosition` actually moves the window (false on Wayland).
    can_set_window_position: bool,
    /// Whether `Window.position` returns a real value (false on Wayland).
    can_query_window_position: bool,
    /// Whether global (desktop-wide) input capture is permitted.
    can_capture_global_input: bool,
    /// Whether DPI scale is reported per-monitor (vs. a single desktop scale).
    high_dpi_scale_per_monitor: bool,
};
