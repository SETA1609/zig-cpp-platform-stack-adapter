# Milestone v0.6.0 — SDL3 minimal backend

> The plan to reach the first usable release. Replaces the GLFW hello-world template with an SDL3 backend: a window, an event pump, renderer selection (Vulkan/OpenGL/none), per-OS native handle getters, and minimal action binding. Roadmap context: [`ROADMAP.md`](ROADMAP.md).
>
> **Goal:** tag `v0.6.0`.
>
> **Definition of done:** the smoke test opens + closes a window on Linux (X11 + Wayland); the active-display native handle getter returns non-null; a GL context can be created on the OpenGL path; `zig build` produces a static lib exporting the `platform` module; CI green on `x86_64-linux-gnu` + `x86_64-windows-gnu`.

Each `[ ]` is one atomic commit (Conventional Commits, subject ≤ 72 chars).

## Items

- [ ] **P1.1** Add the SDL3 dependency. `build.zig.zon`: add [`castholm/SDL`](https://github.com/castholm/SDL) pinned to a specific tag/commit; elect HIDAPI = BSD-3-Clause and note it in this repo's license notices.
  - Files: `build.zig.zon`
  - Acceptance: `zig fetch` resolves; hash pinned
  - Commit: `chore(zon): add castholm/SDL dependency (pinned; HIDAPI=BSD-3-Clause)`

- [ ] **P1.2** Turn the template into a library. `build.zig`: drop the hello-world executable; link the `SDL3` artifact; expose a `platform` module rooted at `src/root.zig`; scaffold `-Dplatform_backend=sdl3` (default).
  - Files: `build.zig`
  - Acceptance: `zig build` produces a static lib; a consumer can `@import("platform")`
  - Commit: `feat(build): expose platform module + link SDL3 (castholm) static lib`

- [ ] **P1.3** Shared types. `src/common.zig`: `Event` union, `KeyCode`, `WindowOptions` (incl. `renderer`)/`Size`/`Position`, `ActionId`.
  - Files: `src/common.zig`
  - Commit: `feat(api): common types — Event, KeyCode, WindowOptions, ActionId`

- [ ] **P1.4** Public API skeleton. `src/root.zig`: full v1.0 surface signatures, all `@panic("not implemented")` except the calls P1.5–P1.7 make real.
  - Files: `src/root.zig`
  - Commit: `feat(api): stub public API surface (panic-on-call)`

- [ ] **P1.5** SDL3 window + events. `src/backend/sdl3.zig`: real `Window.create`/`destroy`/`shouldClose`, `nextEvent`/`pollAllEvents` mapping `SDL_PollEvent` → `Event`; honor `WindowOptions.renderer`.
  - Files: `src/backend/sdl3.zig`
  - Acceptance: window opens 1280×720; close event delivered as `.close`
  - Commit: `feat(sdl3): real Window create/destroy + event pump`

- [ ] **P1.6** Surface prerequisites — both paths. Vulkan: `getX11Handle`/`getWaylandHandle`/`getWin32Handle`/`getAndroidHandle` via `SDL_GetWindowProperties` + `requiredVulkanInstanceExtensions()`. OpenGL: `glCreateContext`/`glMakeCurrent`/`glSwapWindow`/`glSetSwapInterval`/`glGetProcAddress` via `SDL_GL_*`.
  - Files: `src/backend/sdl3.zig`, `src/native_handle.zig`
  - Acceptance: active-display getter returns non-null (others `null`); extension list non-empty; a GL context creates + swaps
  - Commit: `feat(sdl3): native handle getters + Vulkan extensions + GL context`

- [ ] **P1.7** Minimal action input. `bindAction`/`actionPressed`/`actionJustPressed` for key bindings — enough for `menu_pause`→ESC. Contexts + injection + axis modifiers deferred to v0.7.0.
  - Files: `src/action_input.zig`
  - Acceptance: `bindAction(.menu_pause, .{ .key = .escape })` → `actionJustPressed(.menu_pause)` true on ESC
  - Commit: `feat(input): minimal key action binding (bindAction/actionPressed)`

- [ ] **P1.8** Smoke test. `src/tests/`: open + close a window; assert the active-display native getter is non-null.
  - Files: `src/tests/smoke.zig`
  - Acceptance: `zig build test` passes (windowed locally; headless guard in CI)
  - Commit: `test: smoke test — open/close window + native handle non-null`

- [ ] **P1.9** CI. `.github/workflows/build.yml`: build as a static lib on `x86_64-linux-gnu` + `x86_64-windows-gnu`; run `zig fmt --check` + the smoke test.
  - Files: `.github/workflows/build.yml`
  - Commit: `ci: build on linux + windows targets`

- [ ] **P1.10** Tag + push `v0.6.0`. Downstream consumers bump their pinned dependency.

## Deferred to later versions

- v0.7.0 — full action input (contexts, injection, axis modifiers, TOML-loaded bindings)
- v0.8.0 — gamepad / sensor / haptic / clipboard / paths / power / IME
- v0.9.0 — `SDL_Renderer` 2D primitives
- v0.10.0 — `SDL_AudioStream` default audio
