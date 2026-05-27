# Roadmap — zig-cpp-platform-stack-adapter

> The versioned plan for this adapter's public API surface, backed by **SDL3** (built via [`castholm/SDL`](https://github.com/castholm/SDL)). Each version maps to a [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) phase that consumes it. Sprint-level breakdown: [`sprint.md`](sprint.md).
>
> **This supersedes the README's "GLFW → pure-Zig native" plan.** That migration was withdrawn 2026-05-26 — SDL3 is the backend through v1.0+; the `backend/native/` slot is retained as scaffolding only. Authority: [`docs/specs/platform.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/specs/platform.md) + project memory `project-platform-backend-sdl3`. (The README still describes the old plan — flagged for update in this sprint, item P1.10.)

## Backend

| Sub-repo version | Backend | Status |
| --- | --- | --- |
| v0.x – v0.5 | GLFW (zlib) — hello-world only | Superseded |
| **v0.6 onward** | **SDL3** (zlib core) via the [`castholm/SDL`](https://github.com/castholm/SDL) `build.zig.zon` dependency (pinned tag/commit; HIDAPI elected BSD-3-Clause) | **Active** |
| ~~Pure-Zig native~~ | X11 / Wayland / Win32 / Android in pure Zig | Withdrawn |

SDL3 is **not** vendored as a `vendor/SDL/` git submodule — it's a pinned `build.zig.zon` dependency on [`castholm/SDL`](https://github.com/castholm/SDL). See [zVoxRealms `external-libs-catalog.md` § Building SDL3](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/external-libs-catalog.md). This also supersedes the `vendor/SDL/` step in the parent platform spec's backend-swap plan (the spec is older than the castholm decision).

## Renderer-agnostic by design

This adapter does windowing + input, **not** rendering — so it stays neutral about the GPU API. Three independent paths hang off the same window, chosen via `WindowOptions.renderer`:

- **`.vulkan`** — per-OS native handle getters + `requiredVulkanInstanceExtensions()`; pairs with the [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter). No Vulkan types cross the API.
- **`.opengl`** — a managed GL context + `glSwapWindow`/`glGetProcAddress`/swap-interval (SDL3 `SDL_GL_*`). The GL loader lives in the *consumer*; this adapter ships no GL bindings.
- **`.none`** — window + events only (or `SDL_Renderer` 2D primitives at v0.9.0).

This is what lets a renderer migrate **from OpenGL to Vulkan in stages**: keep the GL path shipping while the Vulkan path is built against the *same* platform API, then flip the window's renderer once it reaches parity. The platform layer is the unchanged floor under that migration — see [`mission.md`](mission.md) § The staged migration. Both the Vulkan and OpenGL paths land in **v0.6.0** (each is a thin set of SDL3 calls).

## Version milestones

| Version | Scope | Unblocks (zVoxRealms phase) |
| --- | --- | --- |
| **v0.6.0** | SDL3 minimal: `Window` create/destroy, event pump (`nextEvent`/`pollAllEvents`), **renderer selection (`vulkan`/`opengl`/`none`)**, per-OS native handle getters + `requiredVulkanInstanceExtensions()` (Vulkan path), GL context (`glCreateContext`/`glSwapWindow`/`glGetProcAddress`) (OpenGL path), minimal key action binding (`menu_pause`→ESC) | **Phase 1** — window opens, Vulkan **or** OpenGL surface usable, ESC quits |
| **v0.7.0** | Action-mapped input complete: `bindAction`/`actionPressed`/`actionValue`, axis modifiers (deadzone/smooth/scale/invert), Input Mapping Contexts (push/pop stack), synthetic injection; bindings load from TOML | Phase 2+ (gameplay input; needs TOML) |
| **v0.8.0** | Device & I/O breadth: gamepad (Steam Input mapping), sensor (gyro/IMU), haptic (rumble), clipboard, filesystem paths (`appDataDir`/`appCacheDir`), power info, IME / text input | Phase 5–8 (gameplay polish) |
| **v0.9.0** | 2D rendering primitives (`SDL_Renderer`) for the engine widget kit | Phase 7.5 (UI widgets) |
| **v0.10.0** | Default audio backend (`SDL_AudioStream`) | Phase 7.5 (audio) |
| **v1.0.0** | Full v1.0 API surface stable; capability flags complete; Linux (X11 + Wayland) + Windows + Android validated in CI; macOS deferred per `mission.md` | Phase 13 (ship) |

Versions ≤ v0.6.0 are anchored by the parent [`sprint.md` § B.2](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/sprint.md). Later versions are this adapter's own continuation and may resequence as gameplay phases firm up.

## Design rules (non-negotiable)

The four rules that keep a future backend swap cheap (SDL3 → SDL4, or → a native backend). Full text: [`docs/specs/platform.md` § The four design rules](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/specs/platform.md).

1. **Design the API to the engine's needs, not SDL3's idioms** — no `SDL_*` types or callback registration cross the public API.
2. **Per-OS native handle getters; the renderer has matching creators; the engine bridges.** No shared type between this adapter and [`zig-cpp-vulkan-stack-adapter`](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter).
3. **Pick engine-canonical behavior; document divergence honestly** via capability flags.
4. **Integration tests run against every supported backend** (today: SDL3 only).

## Out of scope / deferred

- **macOS backend** — deferred post-v1.0 per `mission.md`.
- **Multi-window** — single primary window for v1.0; editor multi-window deferred to Phase 12.
- **Pure-Zig native backend** — withdrawn; `backend/native/` retained as build-time scaffolding only, not on the roadmap.

## Cross-reference

- API contract: [`docs/specs/platform.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/specs/platform.md)
- Catalog entry: [`external-libs-catalog.md` § 3 Platform-stack](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/external-libs-catalog.md)
- Sibling adapter: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)
- Sprint plan: [`sprint.md`](sprint.md)
