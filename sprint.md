# Sprint 1 — v0.6.0: SDL3 minimal backend

> First real backend work in this sub-repo. Replaces the GLFW hello-world template with an SDL3 backend that unblocks [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) Phase 1 (window opens, events pump, Vulkan surface creatable, ESC quits). Roadmap context: [`ROADMAP.md`](ROADMAP.md).
>
> **Sprint goal:** tag `v0.6.0` — the SDL3 backend exposing `Window` + event pump + per-OS native handle getters + `requiredVulkanInstanceExtensions()` + minimal key action binding.
>
> **Definition of done:** smoke test opens + closes an SDL3 window on Linux (X11 + Wayland); the active-display native handle getter returns non-null; `zig build` produces a static lib exporting the `platform` module; CI green on `x86_64-linux-gnu` + `x86_64-windows-gnu`.

Each `[ ]` maps to one atomic sub-repo commit per [zVoxRealms commit rules](https://github.com/SETA1609/zigVoxelWorlds/blob/main/CONTRIBUTING.md).

## Items

- [ ] **P1.1** Add the SDL3 dependency. `build.zig.zon`: add [`castholm/SDL`](https://github.com/castholm/SDL) pinned to a specific tag/commit; elect HIDAPI = BSD-3-Clause; record the election in the parent project's `LICENSES.md`.
  - Files: `build.zig.zon`
  - Acceptance: `zig fetch` resolves; hash pinned in the manifest
  - Commit: `chore(zon): add castholm/SDL dependency (pinned; HIDAPI=BSD-3-Clause)`

- [ ] **P1.2** Turn the template into a library. `build.zig`: drop the hello-world executable; link the `SDL3` artifact from the castholm dep; expose a `platform` module rooted at `src/root.zig`; scaffold `-Dplatform_backend=sdl3` (default).
  - Files: `build.zig`
  - Acceptance: `zig build` produces a static lib; a consumer can `@import("platform")`
  - Commit: `feat(build): expose platform module + link SDL3 (castholm) static lib`

- [ ] **P1.3** Shared types. `src/common.zig`: `Event` union, `KeyCode`, `WindowOptions`/`Size`/`Position`, engine-core `ActionId` enum — per spec § Public API surface.
  - Files: `src/common.zig`
  - Commit: `feat(api): common types — Event, KeyCode, WindowOptions, ActionId`

- [ ] **P1.4** Public API skeleton. `src/root.zig`: the full v1.0 surface signatures, all `@panic("not implemented")` except the calls P1.5–P1.7 make real.
  - Files: `src/root.zig`
  - Commit: `feat(api): stub public API surface (panic-on-call) per platform spec`

- [ ] **P1.5** SDL3 window + events. `src/backend/sdl3.zig`: real `Window.create`/`destroy`/`shouldClose`, `nextEvent`/`pollAllEvents` mapping `SDL_PollEvent` → engine `Event`.
  - Files: `src/backend/sdl3.zig`
  - Acceptance: window opens 1280×720; close event delivered as `.close`
  - Commit: `feat(sdl3): real Window create/destroy + event pump`

- [ ] **P1.6** Native handle getters + Vulkan extensions. `getX11Handle`/`getWaylandHandle`/`getWin32Handle`/`getAndroidHandle` via `SDL_GetWindowProperties`; `requiredVulkanInstanceExtensions()` via `SDL_Vulkan_GetInstanceExtensions`. Per spec Rule 2 — raw primitives only, no Vulkan types.
  - Files: `src/backend/sdl3.zig`, `src/native_handle.zig`
  - Acceptance: active-display getter returns non-null raw primitives, others `null`; extension list non-empty
  - Commit: `feat(sdl3): per-OS native handle getters + required Vulkan instance extensions`

- [ ] **P1.7** Minimal action input. `bindAction`/`actionPressed`/`actionJustPressed` for key bindings — enough for `menu_pause`→ESC. Full context stack + injection + axis modifiers deferred to v0.7.0.
  - Files: `src/action_input.zig`
  - Acceptance: `bindAction(.menu_pause, .{ .key = .escape })` → `actionJustPressed(.menu_pause)` true on ESC
  - Commit: `feat(input): minimal key action binding (bindAction/actionPressed)`

- [ ] **P1.8** Smoke test. `src/tests/`: open + close a window; assert the active-display native getter is non-null.
  - Files: `src/tests/smoke.zig`
  - Acceptance: `zig build test` passes (windowed locally; headless guard in CI)
  - Commit: `test: smoke test — open/close SDL3 window + native handle non-null`

- [ ] **P1.9** CI. `.github/workflows/build.yml`: build the adapter as a static lib on `x86_64-linux-gnu` + `x86_64-windows-gnu`; run `zig fmt --check` + the smoke test.
  - Files: `.github/workflows/build.yml`
  - Commit: `ci: build platform adapter on linux + windows targets`

- [ ] **P1.10** Docs. Update `README.md` — replace the stale "GLFW → pure-Zig native" section with "SDL3 via castholm/SDL"; flip Status to "Phase 1 — SDL3 backend (v0.6.0)".
  - Files: `README.md`
  - Commit: `docs(readme): SDL3/castholm backend; drop withdrawn GLFW→native plan`

- [ ] **P1.11** Tag + push. Tag `v0.6.0`; push the tag. The parent engine then bumps the dep pin in its `build.zig.zon`.
  - Parent commit: `chore(deps): bump platform-adapter → v0.6.0 (SDL3 backend)`

## Deferred to later versions (not this sprint)

- v0.7.0 — full action input (contexts, injection, axis modifiers, TOML-loaded bindings)
- v0.8.0 — gamepad / sensor / haptic / clipboard / paths / power / IME
- v0.9.0 — `SDL_Renderer` 2D primitives for the widget kit
- v0.10.0 — `SDL_AudioStream` default audio

## What you write yourself vs. what AI helps with

Per [zVoxRealms `docs/guard.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/guard.md) — this is a learning project:

- **You write all `.zig` / `.c` / `.cpp` backend code by hand** (the bodies of P1.2–P1.8).
- **AI helps with:** reviewing your code, debugging compile errors you paste, drafting `build.zig.zon` / CI / `.clang-format` config, documentation, scaffolding empty files.
- **AI does not write:** the SDL3 backend bodies, the event mapping, the native-handle extraction, or the action-input layer.
