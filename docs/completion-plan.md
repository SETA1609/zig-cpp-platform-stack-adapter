# Completion plan — zig-cpp-platform-stack-adapter → 1.0

> The path from today's state to a stable **v1.0.0**. Milestone targets live in
> [`ROADMAP.md`](ROADMAP.md); this doc is the *ordered, actionable* breakdown.
> Every feature group follows the house workflow: a gated TDD session under
> `src/tests/tdd/` (red→green), one atomic commit per group, a
> `// WHEN … · GIVEN … · THEN …` spec per test, and the platform-only `nm`
> decoupling check stays green (zero `vk*`/`VK_` symbols).

## Where we are

✅ `Window` create/destroy + size/position/title/scaleFactor/shouldClose ·
**runtime window state** (fullscreen/resizable/bordered/min-max + getters,
minimize/maximize/restore/raise) · **mouse capture & cursor** (relative mode,
grab, warp, show/hide/visible) · event pump (`nextEvent`/`pollAllEvents`/`events`)
· key action binding (`bindAction`/`actionPressed`/`actionJust*`) · **X11 +
Wayland** native handles + `requiredVulkanInstanceExtensions` · time.

🚧 **14 public functions still `@panic`** (5 input-context, 3 filesystem-path,
6 OpenGL), plus `capabilities()`. Mapped to milestones below.

## Phase P1 — finish v0.6 (GL path + capabilities)

Size: **S–M** · CI: Linux-runnable (needs a display + a GL context).

- [ ] New `13_gl_context_test.zig` session: implement `glCreateContext` /
      `glMakeCurrent` / `glSwapWindow` / `glSetSwapInterval` / `glGetProcAddress`
      / `glDestroyContext` via `SDL_GL_*` on an `.opengl` window. (Makes the
      advertised OpenGL renderer real.)
- [ ] Implement `capabilities()` (currently `@panic`) — turns the 3 gated
      `09_capabilities` tests green. 1.0 requires "capability flags complete."

## Phase P2 — finish v0.7 (input depth)

Size: **M** · mostly turns the **~26 currently-skipped** tests green.

- [ ] **Input Mapping Contexts**: `pushContext` / `popContext` /
      `replaceTopContext` / `activeContext` / `isContextActive` — a context stack
      the action resolver consults. Un-skips most of `08_context` (+ some `07_action`).
- [ ] **Axis modifiers** behind `actionValue` (deadzone / smooth / scale / invert
      — fields already on `GamepadAxisBinding`).
- [ ] **Synthetic injection** (`injectAction`).
- [ ] **TOML-loadable bindings** — *decision: a small TOML dep vs. a hand-rolled
      minimal parser (leaning hand-rolled to keep the dep surface clean).*

## Phase P3 — v0.8 device & I/O breadth

Size: **L** · several sessions. Quick wins first.

- [ ] `applicationDataDirectory` / `applicationCacheDirectory` (`SDL_GetPrefPath` / `GetBasePath`),
      `openWithSystemDefault` (`SDL_OpenURL`) — all 3 currently `@panic`.
- [ ] Clipboard (get/set), IME / text-input control (`SDL_StartTextInput` / `Stop`).
- [ ] Gamepad **device** API: open / enumerate / close + **rumble**,
      connect/disconnect lifecycle (events already exist).
- [ ] Sensor (gyro/IMU), haptic, power info (`SDL_GetPowerInfo`).

## Phase P4 — v0.9 (2D renderer)

Size: **M** · `SDL_Renderer` primitives (clear / rect / line / texture) behind a
clean Zig API for the `.none` / HUD path.

## Phase P5 — v0.10 (audio)

Size: **M** · `SDL_AudioStream`: open device, queue/stream PCM, load WAV.
*Decision: mp3 playback needs a decoder — add one, or keep PCM/WAV-only for 1.0?*

## Phase P6 — 1.0 hardening

Size: **M–L** · infra + cross-platform.

- [ ] Validate **Win32 / Android** native-handle getters on their own OSes (they
      return `null` on Linux today, unproven elsewhere).
- [ ] **macOS (in scope, contributor-led — not maintainer-tested, see
      [`CONTRIBUTING.md`](../CONTRIBUTING.md)):** `getCocoaHandle` →
      `CAMetalLayer`, pairing with the vulkan lib's `createMetalSurface`.
- [ ] **CI matrix**: Linux X11 + Wayland (headless compositor for the
      window/event suite), Windows, Android build.
- [ ] Wire the **platform-only `nm` gate** (zero `vk*` symbols) as a hard CI gate;
      complete capability-flag divergence docs; pin `castholm/SDL` to a released
      tag; **freeze the API** → tag **v1.0.0**.

## Critical path

P1 → P2 → P3 → (P4, P5 in parallel) → P6. P1 and P2 are the highest-value next
steps — they finish the OpenGL renderer and the rebindable/context-aware input
that real games need, and clear most of the skipped suite.

## Out of scope for 1.0

Multi-window (single primary window for 1.0) · a pure-Zig native backend
(contributor-led, `backend/native/` slot retained) — see [`ROADMAP.md`](ROADMAP.md).
