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
Wayland** native handles + `requiredVulkanInstanceExtensions` · time · **OpenGL
context path** (`glCreateContext`/…/`glDestroyContext`) · **`capabilities()`**.
**v0.6.0 is feature-complete.**

🚧 **8 public functions still `@panic`** (5 input-context, 3 filesystem-path).
Mapped to milestones below. *(The v0.8–v0.10 device/IO/cpu/audio surfaces are
scaffolded-but-stubbed too — see ROADMAP.)*

## Phase P1 — finish v0.6 (GL path + capabilities) — ✅ DONE

Size: **S–M** · CI: Linux-runnable (needs a display + a GL context).

- [x] `13_gl_context_test.zig`: `glCreateContext` / `glMakeCurrent` /
      `glSwapWindow` / `glSetSwapInterval` / `glGetProcAddress` /
      `glDestroyContext` via `SDL_GL_*` on an `.opengl` window — implemented; the
      OpenGL renderer path is real. *(No "unknown name → null" assertion: GLX/EGL
      return a non-null trampoline for any name — validate via the GL version.)*
- [x] `capabilities()` implemented (`SDL_GetCurrentVideoDriver`; Wayland forbids
      self-position) — the `09_capabilities` tests pass.

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

## Phase P4 — v0.9 (CPU framebuffer)

Size: **M** · the `.cpu` software-framebuffer path (`SDL_GetWindowSurface`; write
BGRA pixels on CPU) behind a clean Zig API — covers 2D / HUD / software
rasterizers without dragging a GPU API. (The SDL_Renderer-based 2D `Canvas` was
dropped: 2D is served by `.cpu` or the GPU renderer paths.)

## Phase P5 — v0.10 (audio)

Size: **M** · `SDL_AudioStream`: open device, queue/stream PCM, load WAV.
*Decision: mp3 playback needs a decoder — add one, or keep PCM/WAV-only for 1.0?*

## Phase P6 — 1.0 hardening

Size: **M–L** · infra + cross-platform.

- [ ] Validate **Win32 / Android** native-handle getters on their own OSes (they
      return `null` on Linux today, unproven elsewhere).
- [ ] **macOS (in scope, contributor-led — the author has no macOS hardware to
      test on, so it ships only via a self-tested contributor PR; see
      [`CONTRIBUTING.md`](../CONTRIBUTING.md)):** the `.metal` hand-off —
      `getCocoaHandle` → `CAMetalLayer`, pairing with the vulkan lib's
      `createMetalSurface`. SDL3 itself covers macOS.
- [ ] **CI matrix**: Linux X11 + Wayland (headless compositor for the
      window/event suite), Windows, Android build.
- [ ] Wire the **platform-only `nm` gate** (zero `vk*` symbols) as a hard CI gate;
      complete capability-flag divergence docs; pin `castholm/SDL` to a released
      tag; **freeze the API** → tag **v1.0.0** (all SDL3-backed features
      implemented & frozen).

## Critical path

P1 → P2 → P3 → (P4, P5 in parallel) → P6. P1 and P2 are the highest-value next
steps — they finish the OpenGL renderer and the rebindable/context-aware input
that real games need, and clear most of the skipped suite.

## Out of scope for 1.0

Multi-window (single primary window for 1.0) · the **native per-OS backends**
(X11 / Wayland / Win32 / Android NDK / Cocoa) — **planned post-1.0** (the v1.x
line), same public API with no SDL3; contributor-led, `backend/native/` slot
retained — see [`ROADMAP.md`](ROADMAP.md).
