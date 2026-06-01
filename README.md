# zig-cpp-platform-stack-adapter

A standalone **Zig library**: one stable, **renderer-agnostic** API for windowing, input, time, file paths, and per-OS native handles — backed by [SDL3](https://github.com/libsdl-org/SDL). Use it with **Vulkan**, **OpenGL**, or **headless**; the backend can change underneath without your code changing.

**License:** [MIT](LICENSE) · **Requires:** Zig 0.16+ · **Status:** pre-1.0, single-maintainer

> **Status detail:** the **v0.6.0 core is implemented** on the SDL3 backend —
> windowing (`Window` create/destroy/size/setSize/scaleFactor/setTitle/
> setPosition/position/shouldClose), the event pump (`pollAllEvents` /
> `nextEvent` / `events`), time (`now` / `perfFreq` / `perfCounter` / `sleep`),
> **action-mapped input** (`bindAction` / `actionPressed` / `actionJustPressed` /
> `injectAction`, generic over *your own* action enum), and the **Vulkan
> hand-off** (per-OS native-handle getters + `requiredVulkanInstanceExtensions`).
> Still `@panic("not implemented")` stubs: the **OpenGL path**
> (`glCreateContext`/…), **input contexts** (`pushContext`/…),
> **`capabilities()`**, and **filesystem paths** (`appDataDir`/…) — see
> [`docs/ROADMAP.md`](docs/ROADMAP.md). Calling a not-yet-implemented function
> traps at runtime with a clear message.

---

## Documentation

- [`docs/vision.md`](docs/vision.md) — what this library is for; why it's renderer-agnostic
- [`docs/mission.md`](docs/mission.md) — concrete commitments (Vulkan + OpenGL + headless paths)
- [`docs/api.md`](docs/api.md) — intended public API surface (signatures + semantics)
- [`docs/enum-values.md`](docs/enum-values.md) — stable enum name→value maps (for TOML/JSON bindings & serialization)
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — versioned milestones (v0.6.0 → v1.0.0)
- [`docs/sprint.md`](docs/sprint.md) — current milestone plan
- [`docs/validation-apps.md`](docs/validation-apps.md) — standalone test apps + completion checklist
- [`docs/dependencies.md`](docs/dependencies.md) — consumed libraries + Zig/C/C++ language split
- [`docs/cheat_sheet.md`](docs/cheat_sheet.md) — Zig/C/C++ cross-language field guide
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to contribute (OpenGL + native-backend PRs welcome)
- [`SECURITY.md`](SECURITY.md) — security policy

## What it is

A single Zig package you import as one dependency to get cross-platform windowing + input with idiomatic Zig types. Your code imports `platform` and calls a stable API; it never sees the backend. The backend is **SDL3** today and could become a native backend or a future SDL without your code changing — that decoupling is the whole reason this exists as its own library.

The public surface (see [`docs/mission.md`](docs/mission.md) for the full list):

- Opaque `Window` + `WindowOptions`
- A queued `Event` union (`key` / `mouse_*` / `resize` / `focus` / `close` / `gamepad` / `text_input` / `file_drop`)
- **Action-mapped input** — `bindAction` / `actionPressed` / `actionValue`, stackable input contexts, synthetic injection. The action/context **vocabulary is yours** (pass your own enum); the library names none, and raw key codes stay inside the backend.
- Time, app data/cache paths, clipboard, IME, gamepad, sensor, haptic, power
- Per-OS native handle getters + the prerequisites for Vulkan **or** OpenGL surface creation

## Renderer-agnostic — Vulkan, OpenGL, or headless

This library does windowing + input, **not** rendering, so it stays neutral about the GPU API. Three paths hang off the same window, chosen via `WindowOptions.renderer`:

| Path | The library gives you | For |
| --- | --- | --- |
| **`.vulkan`** | per-OS native handle getters + `requiredVulkanInstanceExtensions()` (raw primitives, no Vulkan types) | your Vulkan renderer / a Vulkan-stack adapter |
| **`.opengl`** | a managed GL context + `glSwapWindow` + `glGetProcAddress` + swap-interval | any OpenGL renderer (the GL loader lives in your code) |
| **`.none`** | window + events only | headless tools, custom 2D |

You are **not** forced onto Vulkan. The OpenGL path is fully supported, and it lets you migrate a renderer **from OpenGL to Vulkan in stages** — keep GL shipping while you build the Vulkan path against the same windowing API, then flip. (Honest limit: a window binds to one GPU API at creation; this is for *switching* renderers, not mixing GL + Vulkan in one window.)

## Quick start

```zig
// build.zig.zon
.dependencies = .{
    .platform = .{
        .url = "git+https://github.com/SETA1609/zig-cpp-platform-stack-adapter.git#<tag>",
        .hash = "...",
    },
},
```

```zig
const platform = @import("platform");

// Your game owns the action vocabulary — the library names no actions.
// Pass values of your own enum to bindAction / actionPressed / injectAction.
const Action = enum(u16) { quit, jump };

try platform.init(.{});
defer platform.deinit();

const window = try platform.Window.create(.{
    .title = "my app",
    .size = .{ .w = 1280, .h = 720 },
    .renderer = .vulkan,   // or .opengl, or .none
});
defer window.destroy();

platform.bindAction(Action.quit, .{ .key = .escape });
while (!window.shouldClose()) {
    platform.pollAllEvents();
    while (platform.nextEvent()) |ev| switch (ev) {
        .close => return,
        .resize => |r| { _ = r; /* recreate swapchain */ },
        else => {},
    };
    if (platform.actionJustPressed(Action.quit)) break;
    // ... render with your GPU API of choice ...
}
```

## Backends

| Backend | Status |
| --- | --- |
| **SDL3** (zlib) — via [`castholm/SDL`](https://github.com/castholm/SDL), pinned in `build.zig.zon` | active, default |
| Pure-Zig native (X11/Wayland/Win32/Android) | **not maintainer-led** — a solid, tested PR is welcome; the `backend/native/` slot exists for it. See [CONTRIBUTING](CONTRIBUTING.md). |

## Design rules (what keeps a backend swap cheap)

1. The API is shaped to your app's needs, not the backend's idioms — no `SDL_*` types cross it.
2. Per-OS native handle getters return raw primitives; no shared type with any renderer library.
3. Engine-canonical behavior, with honest per-OS divergence exposed as capability flags.
4. Integration tests run against every supported backend.

## Companion & origin

- Companion: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) — pair the two for a full window→Vulkan-surface path (each is usable alone).
- Built for and used by the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) engine project, but designed to **stand alone** — usable in any Zig project. Deeper design rationale lives in that project's platform spec.
