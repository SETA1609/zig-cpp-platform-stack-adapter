# zig-cpp-platform-stack-adapter

A standalone **Zig library**: one stable, **renderer-agnostic** API for windowing, input, time, file paths, and per-OS native handles — backed by [SDL3](https://github.com/libsdl-org/SDL). Use it with **Vulkan**, **OpenGL**, a **CPU framebuffer**, **Metal**, **D3D**, or **headless**; the backend can change underneath without your code changing.

**License:** [MIT](LICENSE) · **Requires:** Zig 0.16+ · **Status:** pre-1.0, single-maintainer

> **Status detail:** the **v0.6.0 core is implemented** on the SDL3 backend —
> windowing (`Window` create/destroy/size/setSize/scaleFactor/setTitle/
> setPosition/position/shouldClose), the event pump (`pollAllEvents` /
> `nextEvent` / `events`), time (`now` / `performanceFrequency` / `performanceCounter` / `sleep`),
> **action-mapped input** (`bindAction` / `actionPressed` / `actionJustPressed` /
> `injectAction`, generic over *your own* action enum), and the **Vulkan
> hand-off** (per-OS native-handle getters + `requiredVulkanInstanceExtensions`).
> **v0.7.0** added **runtime window state** (`setFullscreen`/`setResizable`/
> `setBordered` + the `is*` getters, `setMinSize`/`setMaxSize` + getters,
> `minimize`/`maximize`/`restore`/`raise`) and **mouse capture & cursor**
> (`setRelativeMouseMode`/`relativeMouseMode`, `warpMouse`, `setMouseGrab`/
> `mouseGrabbed`, global `showCursor`/`hideCursor`/`cursorVisible`).
> Still `@panic("not implemented")` stubs: the **OpenGL context path**
> (`glCreateContext`/…, now gated in `13_gl_context_test.zig`), **input contexts** (`pushContext`/…),
> **`capabilities()`**, and **filesystem paths** (`applicationDataDirectory`/…) — see
> [`docs/ROADMAP.md`](docs/ROADMAP.md). Calling a not-yet-implemented function
> traps at runtime with a clear message.

---

## Documentation

- [`docs/getting-started.md`](docs/getting-started.md) — **start here**: add the dep, wire the build, a minimal window + input app
- [`docs/sdl3-cheat-sheet.md`](docs/sdl3-cheat-sheet.md) — what SDL3 is + how it works (the backend), with deep-dive links
- [`docs/vision.md`](docs/vision.md) — what this library is for; why it's renderer-agnostic
- [`docs/mission.md`](docs/mission.md) — concrete commitments (Vulkan + OpenGL + headless paths)
- [`docs/api.md`](docs/api.md) — intended public API surface (signatures + semantics)
- [`docs/enum-values.md`](docs/enum-values.md) — stable enum name→value maps (for TOML/JSON bindings & serialization)
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — versioned milestones (v0.6.0 → v1.0.0)
- [`docs/completion-plan.md`](docs/completion-plan.md) — the path to v1.0
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

## Renderer-agnostic — Vulkan, OpenGL, CPU, Metal, D3D, or headless

This library does windowing + input, **not** rendering, so it stays neutral about the GPU API. Six paths hang off the same window, chosen via `WindowOptions.renderer` — in every GPU case the library hands back **raw OS primitives** and links no graphics API:

| Path | The library gives you | For |
| --- | --- | --- |
| **`.none`** | window + events only | headless tools |
| **`.vulkan`** | per-OS native handle getters + `requiredVulkanInstanceExtensions()` (raw primitives, no Vulkan types) | your Vulkan renderer / a Vulkan-stack adapter |
| **`.opengl`** | a managed GL context + `glSwapWindow` + `glGetProcAddress` + swap-interval | any OpenGL renderer (the GL loader lives in your code) |
| **`.cpu`** | a software framebuffer (`SDL_GetWindowSurface`; write BGRA pixels on CPU) | software rasterizers, 2D, custom blitters |
| **`.metal`** | a `CAMetalLayer` via `getCocoaHandle` (raw primitive) | your Metal renderer (macOS / iOS) |
| **`.directx`** | the `HWND` via `getWin32Handle` (raw primitive) | your D3D11 / D3D12 device (Windows) |

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
    .renderer = .vulkan,   // or .opengl / .cpu / .metal / .directx / .none
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

The **backend** (the windowing implementation) is a separate axis from the per-window **renderer** above. The public API is identical across backends.

| Backend | Status |
| --- | --- |
| **SDL3** (zlib) — via [`castholm/SDL`](https://github.com/castholm/SDL), pinned in `build.zig.zon` | active, default — the backend through **v1.0.0** (all SDL3-backed features implemented & frozen) |
| Native per-OS backends (X11 / Wayland / Win32 / Android NDK / Cocoa) | **planned post-1.0** (the v1.x line) — same public API, no SDL3. Contributor PRs welcome; the `backend/native/` slot exists for it. See [CONTRIBUTING](CONTRIBUTING.md). |

> **macOS is contributor-led:** SDL3 covers macOS, but the author has no macOS hardware to test on, so anything macOS-specific (the `.metal` hand-off, a native Cocoa backend) ships only via a self-tested contributor PR.

## Design rules (what keeps a backend swap cheap)

1. The API is shaped to your app's needs, not the backend's idioms — no `SDL_*` types cross it.
2. Per-OS native handle getters return raw primitives; no shared type with any renderer library.
3. Engine-canonical behavior, with honest per-OS divergence exposed as capability flags.
4. Integration tests run against every supported backend.

## Build system

The build follows a three-tier DAG pattern shared with the sibling libraries:

| Layer | File | Role |
|-------|------|------|
| **Root** | `build.zig` | Entry point; resolves target/optimize, delegates to the three sub-steps |
| **Modules** | `build/modules.zig` | Creates the `platform` Zig module (`src/root.zig`), pulls in the SDL3 dependency, produces a `platform` static-library artifact |
| **Tests** | `build/tests.zig` | Wires `test` (contract unit tests via `src/tests/api_test.zig`) and `test-tdd` (behavioural TDD suite via `src/tests/tdd/main.zig`) |
| **Dev** | `build/dev.zig` | Creates a smoke demo (`demo/main.zig`) that imports the module like a downstream consumer; registers the `pipeline` default step |

### Build steps

| Command | What it runs |
|---------|-------------|
| `zig build` | **pipeline** — build the static library (`zig-out/lib/libplatform.a`) |
| `zig build test` | Contract unit tests (public API signatures, error sets, enum discriminants) |
| `zig build test-tdd` | Red→green TDD suite (fails until the backend implementation is complete) |
| `zig build run` | Build + run the smoke demo |

### Flags

- `-Dtarget=<triple>` — cross-compile target (default: host)
- `-Doptimize=<mode>` — Debug / ReleaseFast / ReleaseSafe / ReleaseSmall
- `-Dbackend=<name>` — windowing backend: `sdl3` (default, active), `native` (planned post-1.0)

## Companion & origin

- Companion: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) — pair the two for a full window→Vulkan-surface path (each is usable alone).
- Built for and used by the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) engine project, but designed to **stand alone** — usable in any Zig project. Deeper design rationale lives in that project's platform spec.
