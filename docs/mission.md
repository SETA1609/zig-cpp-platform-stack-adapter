# Mission — zig-cpp-platform-stack-adapter

> The concrete commitments that turn the [vision](vision.md) into a shipped library. Backed by **SDL3** via [`castholm/SDL`](https://github.com/castholm/SDL).

## What we will build

1. **A stable Zig API shaped to the consumer's needs, not SDL3's idioms** — `Window`, an `Event` union, action-mapped input, time, file paths, native handles. No `SDL_*` type crosses the boundary.

2. **Renderer chosen at window creation.** The window binds to one GPU API at creation, so the choice is a `WindowOptions` field. In every GPU case the library hands back raw OS primitives and links no graphics API:
   ```zig
   pub const Renderer = enum { none, vulkan, opengl, cpu, metal, directx };
   // wire ints: none=0, vulkan=1, opengl=2, cpu=3, metal=4, directx=5
   // WindowOptions.renderer: Renderer = .vulkan
   ```

3. **Vulkan path** (no Vulkan types): per-OS `getX11Handle`/`getWaylandHandle`/`getWin32Handle`/`getAndroidHandle` + `requiredVulkanInstanceExtensions()`.

4. **OpenGL path** (no GL types beyond an opaque context + proc-address):
   ```zig
   pub fn glCreateContext(window: *Window) !*GlContext;
   pub fn glMakeCurrent(window: *Window, context: *GlContext) !void;
   pub fn glSwapWindow(window: *Window) void;
   pub fn glSetSwapInterval(interval: i32) void;          // vsync
   pub fn glGetProcAddress(name: [*:0]const u8) ?*const anyopaque;
   ```
   All SDL3-backed (`SDL_GL_*`). The GL loader (glad / a zig-opengl binding) lives in the **consumer**, fed by `glGetProcAddress` — this library ships no GL bindings.

5. **The four design rules upheld** (API-to-consumer-needs · decoupled handles · honest divergence via capability flags · tests-per-backend).

## The staged OpenGL → Vulkan migration this enables

The point of the GL path is **not** mixing GL and Vulkan in one window — SDL binds a window to one GPU API at creation, and GL/Vulkan interop is out of scope for v1.0. The realistic, honest migration is:

1. The renderer ships on the **OpenGL path** (`renderer = .opengl`) — keeps working throughout.
2. A Vulkan renderer is built up against the **same platform API** (`renderer = .vulkan`), behind a build flag or on a separate window.
3. When the Vulkan path reaches parity, flip the window's `renderer` and retire the GL path.

The platform library is the unchanged floor under all three steps. That is what "designed so OpenGL works" buys: the freedom to migrate a renderer without first rewriting windowing/input.

## Success criteria

- Every app in [`validation-apps.md`](validation-apps.md) builds and runs — including a **GL clear-color** app and a **Vulkan clear-color** app against the *same* library build.
- The `nm` decoupling check passes (no GPU-API symbols in a headless binary).
- A backend swap (SDL3 → anything) touches zero consumer source.

## Non-goals

Rendering · GL/Vulkan bindings · asset loading · a consumer's input-context *policy* (the library provides the mechanism; the consumer wires which contexts apply when).
