# Roadmap — zig-cpp-platform-stack-adapter

> The versioned plan for this library's public API surface, backed by **SDL3** (built via [`castholm/SDL`](https://github.com/castholm/SDL)). Sprint-level breakdown: [`sprint.md`](sprint.md).

## Backend

| Version | Backend | Status |
| --- | --- | --- |
| v0.x – v0.5 | GLFW (zlib) — hello-world only | Superseded |
| **v0.6 onward** | **SDL3** (zlib core) via the [`castholm/SDL`](https://github.com/castholm/SDL) `build.zig.zon` dependency (pinned; HIDAPI elected BSD-3-Clause) | **Active** |
| Pure-Zig native (X11/Wayland/Win32/Android) | — | **Not maintainer-led** — a solid, tested PR is welcome ([CONTRIBUTING](../.github/CONTRIBUTING.md)) |

SDL3 is a pinned `build.zig.zon` dependency on [`castholm/SDL`](https://github.com/castholm/SDL), **not** a vendored submodule.

## Renderer-agnostic by design

This library does windowing + input, **not** rendering — so it stays neutral about the GPU API. Three independent paths hang off the same window, chosen via `WindowOptions.renderer`:

- **`.vulkan`** — per-OS native handle getters + `requiredVulkanInstanceExtensions()`. No Vulkan types cross the API.
- **`.opengl`** — a managed GL context + `glSwapWindow`/`glGetProcAddress`/swap-interval (SDL3 `SDL_GL_*`). The GL loader lives in the *consumer*; this library ships no GL bindings.
- **`.none`** — window + events only (or `SDL_Renderer` 2D primitives at v0.9.0).

This lets a renderer migrate **from OpenGL to Vulkan in stages**: keep the GL path shipping while the Vulkan path is built against the *same* API, then flip the window's renderer once it reaches parity — see [`mission.md`](mission.md). Both paths land in **v0.6.0** (each is a thin set of SDL3 calls).

## Version milestones

| Version | Scope | Enables |
| --- | --- | --- |
| **v0.6.0** | SDL3 minimal: `Window` create/destroy, event pump (`nextEvent`/`pollAllEvents`), **renderer selection (`vulkan`/`opengl`/`none`)**, per-OS native handle getters + `requiredVulkanInstanceExtensions()` (Vulkan path), GL context (`glCreateContext`/`glSwapWindow`/`glGetProcAddress`) (OpenGL path), minimal key action binding (`menu_pause`→ESC) | First usable release — open a window, pump events, create a Vulkan **or** OpenGL surface, quit on ESC |
| **v0.7.0** | Action-mapped input complete: `bindAction`/`actionPressed`/`actionValue`, axis modifiers (deadzone/smooth/scale/invert), Input Mapping Contexts (push/pop stack), synthetic injection; bindings loadable from TOML | Rebindable, context-aware input for real games |
| **v0.8.0** | Device & I/O breadth: gamepad (Steam Input mapping), sensor (gyro/IMU), haptic (rumble), clipboard, filesystem paths (`appDataDir`/`appCacheDir`), power info, IME / text input | Full controller + desktop-integration support |
| **v0.9.0** | 2D rendering primitives (`SDL_Renderer`) | A built-in 2D draw path for HUD/widget consumers |
| **v0.10.0** | Default audio backend (`SDL_AudioStream`) | Basic audio without a separate library |
| **v1.0.0** | Full API surface stable; capability flags complete; Linux (X11 + Wayland) + Windows + Android validated in CI; macOS deferred | Production-ready 1.0 |

Versions beyond v0.6.0 may resequence as consumer needs firm up.

## Design rules (non-negotiable)

The four rules that keep a future backend swap cheap (SDL3 → a native backend, or → a future SDL):

1. **Design the API to the consumer's needs, not SDL3's idioms** — no `SDL_*` types or callback registration cross the public API.
2. **Per-OS native handle getters return raw primitives** — no shared type with any renderer library.
3. **Pick canonical behavior; document divergence honestly** via capability flags.
4. **Integration tests run against every supported backend** (today: SDL3 only).

## Out of scope / deferred

- **macOS backend** — deferred; a clean PR is welcome.
- **Multi-window** — single primary window for v1.0; multi-window deferred.
- **Pure-Zig native backend** — not maintainer-led; the `backend/native/` slot is retained as build-time scaffolding, and a solid tested PR is welcome ([CONTRIBUTING](../.github/CONTRIBUTING.md)).

## See also

- Companion library: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)
- Sprint plan: [`sprint.md`](sprint.md) · Test apps: [`validation-apps.md`](validation-apps.md)
- Deeper design rationale: the platform spec in the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) project (the engine this was built for).
