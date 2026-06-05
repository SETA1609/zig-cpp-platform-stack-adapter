# Roadmap — zig-cpp-platform-stack-adapter

> The versioned plan for this library's public API surface, backed by **SDL3** (built via [`castholm/SDL`](https://github.com/castholm/SDL)). Sprint-level breakdown: [`sprint.md`](sprint.md).

## Backend

| Version | Backend | Status |
| --- | --- | --- |
| v0.x – v0.5 | GLFW (zlib) — hello-world only | Superseded |
| **v0.6 onward** | **SDL3** (zlib core) via the [`castholm/SDL`](https://github.com/castholm/SDL) `build.zig.zon` dependency (pinned; HIDAPI elected BSD-3-Clause) | **Active** |
| Pure-Zig native (X11/Wayland/Win32/Android) | — | **Not maintainer-led** — a solid, tested PR is welcome ([CONTRIBUTING](../CONTRIBUTING.md)) |

SDL3 is a pinned `build.zig.zon` dependency on [`castholm/SDL`](https://github.com/castholm/SDL), **not** a vendored submodule.

## Renderer-agnostic by design

This library does windowing + input, **not** rendering — so it stays neutral about the GPU API. Three independent paths hang off the same window, chosen via `WindowOptions.renderer`:

- **`.vulkan`** — per-OS native handle getters + `requiredVulkanInstanceExtensions()`. No Vulkan types cross the API.
- **`.opengl`** — a managed GL context + `glSwapWindow`/`glGetProcAddress`/swap-interval (SDL3 `SDL_GL_*`). The GL loader lives in the *consumer*; this library ships no GL bindings.
- **`.none`** — window + events only (or `SDL_Renderer` 2D primitives at v0.9.0).

This lets a renderer migrate **from OpenGL to Vulkan in stages**: keep the GL path shipping while the Vulkan path is built against the *same* API, then flip the window's renderer once it reaches parity — see [`mission.md`](mission.md). Both paths land in **v0.6.0** (each is a thin set of SDL3 calls).

## Version milestones

**Status:** `stable` = shipped & API-complete on `main` · `dev` = currently in development · `planned` = not yet started. *(No git tags are cut yet — formal tagging is part of the 1.0 hardening pass.)* The **Steps to cut this version** column is the concrete, ordered work that earns the tag — ☑ a shipped patch, ☐ still open, ⊘ superseded; shipped versions list the patches that got them there. House rule for every box: a gated TDD session (red→green), one atomic commit per group, and the platform-only `nm` gate (zero `vk*`/`VK_`) stays green. Fuller TDD detail: [`completion-plan.md`](completion-plan.md).

**Patch convention:** each ☐ task is one **patch** release. Working a minor line `v0.x`, the first task done tags `v0.x.1`, the second `v0.x.2`, and so on (one atomic commit → one patch bump) — the `.N` prefix on each step is the patch it produces. The minor line is **complete** when its last ☐ lands; the next milestone opens the next minor (`v0.(x+1).1`).

| Version | Features | Steps to cut this version | Status |
| --- | --- | --- | --- |
| v0.1.0 – v0.5.0 | GLFW backend (zlib), hello-world only — replaced by the SDL3 rewrite at v0.6. No per-version breakdown kept. | ⊘ **.1** GLFW window + GL context (hello-world). ⊘ **.2** basic event / key input pump. ⊘ **.3** the hello-triangle smoke app. All **superseded** by the SDL3 rewrite at v0.6 — no patches carried forward. | superseded |
| **v0.6.0** | SDL3 minimal: `Window` create/destroy + `size`/`setSize`/`setPosition`/`setTitle`/`scaleFactor`/`shouldClose`; event pump (`nextEvent`/`pollAllEvents`/`events`); renderer selection (`vulkan`/`opengl`/`none`); per-OS native handle getters + `requiredVulkanInstanceExtensions()`; minimal key action binding. | ☑ **.1** SDL3 lifecycle — `init` / `deinit`. ☑ **.2** time — `now` / `performanceCounter` / `performanceFrequency` / `sleep`. ☑ **.3** `Window` create/destroy + `size`/`setSize`/`setPosition`/`setTitle`/`scaleFactor`/`shouldClose`. ☑ **.4** event pump — `nextEvent` / `pollAllEvents` / `events`. ☑ **.5** renderer selection (`vulkan`/`opengl`/`none`). ☑ **.6** per-OS native handle getters + `requiredVulkanInstanceExtensions()`. ☑ **.7** minimal key action binding. ☐ **.8** GL context path via `SDL_GL_*` — `glCreateContext`/`glMakeCurrent`/`glSwapWindow`/`glSetSwapInterval`/`glGetProcAddress`/`glDestroyContext` (`13_gl_context_test.zig`). ☐ **.9** `capabilities()` (turns the 3 gated `09_capabilities` tests green). **Minor done when** the 6 GL fns + `capabilities()` no longer `@panic`. | **dev** |
| **v0.7.0** | Action-mapped input + window/mouse control. **Shipped:** `bindAction`/`unbindAction`/`actionPressed`/`actionJustPressed`/`actionJustReleased`; runtime window state (fullscreen/resizable/bordered + `is*`, min/max size + getters, minimize/maximize/restore/raise); mouse capture & cursor (relative mode, grab, warp, global show/hide/visible). | ☑ **.1** action binding + state — `bindAction`/`unbindAction`/`actionPressed`/`actionJustPressed`/`actionJustReleased`. ☑ **.2** runtime window state — `setFullscreen`/`setResizable`/`setBordered` + `is*`. ☑ **.3** min/max size + getters; `minimize`/`maximize`/`restore`/`raise`. ☑ **.4** mouse capture & cursor — relative mode, grab, warp, global show/hide/visible. ☐ **.5** Input Mapping Contexts — `pushContext`/`popContext`/`replaceTopContext`/`activeContext`/`isContextActive` (un-skips most of `08_context`). ☐ **.6** axis modifiers behind `actionValue` (deadzone/smooth/scale/invert). ☐ **.7** synthetic injection (`injectAction`). ☐ **.8** TOML-loadable bindings *(decision: small dep vs. hand-rolled parser)*. **Minor done when** the ~26 skipped input tests are green. | **dev** |
| **v0.8.0** | Device & I/O breadth: gamepad device API (Steam Input mapping) + rumble, sensor (gyro/IMU), haptic, clipboard, filesystem paths, power info, IME / text input. | ☐ **.1** filesystem paths `applicationDataDirectory`/`applicationCacheDirectory` (`SDL_GetPrefPath`/`GetBasePath`). ☐ **.2** `openWithSystemDefault` (`SDL_OpenURL`). ☐ **.3** clipboard get/set. ☐ **.4** IME / text-input (`SDL_StartTextInput`/`Stop`). ☐ **.5** gamepad device open/enumerate/close. ☐ **.6** gamepad rumble + connect/disconnect lifecycle. ☐ **.7** sensor (gyro/IMU). ☐ **.8** haptic. ☐ **.9** power info (`SDL_GetPowerInfo`). | planned |
| **v0.9.0** | 2D rendering primitives (`SDL_Renderer`) for the `.none` / HUD path. | ☐ **.1** `SDL_Renderer` lifecycle (bound to a `.none` window) + clear. ☐ **.2** rect (fill / outline) + line primitives. ☐ **.3** texture upload + draw (blit). ☐ **.4** wrap behind a clean Zig API for the HUD path + TDD. | planned |
| **v0.10.0** | Default audio backend (`SDL_AudioStream`). | ☐ **.1** `SDL_AudioStream` — open device. ☐ **.2** queue / stream PCM. ☐ **.3** load WAV *(decision: add mp3 decoder vs. PCM/WAV-only for 1.0)*. | planned |
| **v1.0.0** | Full API surface stable; capability flags complete; cross-platform validated; API frozen. | ☐ **.1** validate Win32 + Android native-handle getters on-device (return `null` on Linux today). ☐ **.2** macOS (contributor-led): `getCocoaHandle` → `CAMetalLayer`, pairs with the vulkan lib's `createMetalSurface`. ☐ **.3** CI matrix: Linux X11 + Wayland (headless compositor), Windows, Android build. ☐ **.4** wire the platform-only `nm` gate (zero `vk*`) as a **hard CI gate** + complete capability-flag divergence docs. ☐ **.5** pin `castholm/SDL` to a released tag; **freeze the API** → tag **v1.0.0**. | planned |

Critical path: v0.6 → v0.7 → v0.8 → (v0.9, v0.10 in parallel) → v1.0. No milestones are planned **beyond v1.0.0** yet — multi-window and a pure-Zig native backend are explicitly deferred / contributor-led (see *Out of scope* below). Versions beyond v0.6.0 may resequence as consumer needs firm up.

## Design rules (non-negotiable)

The four rules that keep a future backend swap cheap (SDL3 → a native backend, or → a future SDL):

1. **Design the API to the consumer's needs, not SDL3's idioms** — no `SDL_*` types or callback registration cross the public API.
2. **Per-OS native handle getters return raw primitives** — no shared type with any renderer library.
3. **Pick canonical behavior; document divergence honestly** via capability flags.
4. **Integration tests run against every supported backend** (today: SDL3 only).

## Out of scope / deferred

- **macOS backend** — deferred; a clean PR is welcome.
- **Multi-window** — single primary window for v1.0; multi-window deferred.
- **Pure-Zig native backend** — not maintainer-led; the `backend/native/` slot is retained as build-time scaffolding, and a solid tested PR is welcome ([CONTRIBUTING](../CONTRIBUTING.md)).

## See also

- Companion library: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)
- Sprint plan: [`sprint.md`](sprint.md) · Test apps: [`validation-apps.md`](validation-apps.md)
- Deeper design rationale: the platform spec in the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) project (the engine this was built for).
