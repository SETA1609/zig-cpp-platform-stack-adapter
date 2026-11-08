# Roadmap — zig-cpp-platform-stack-adapter

> The versioned plan for this library's public API surface. Windowing + input, **renderer-agnostic**, on a swappable backend: **SDL3 today**, native per-OS ports **after v1.0**. Actionable breakdown: [`completion-plan.md`](completion-plan.md).

## Backend

The library's public API is backend-neutral; the backend is an implementation detail behind it.

| Backend | Targets | Status |
| --- | --- | --- |
| **SDL3** (zlib core) via the pinned [`castholm/SDL`](https://github.com/castholm/SDL) `build.zig.zon` dependency (HIDAPI elected BSD-3-Clause) | Linux (X11 + Wayland), Windows, macOS, Android, iOS — all through SDL3 | **Active** — the backend **through v1.0.0** |
| **Native per-OS** — X11 · Wayland · Win32 · Android NDK · Cocoa | one direct backend per OS, no SDL3 | **Planned — post-1.0** (the v1.x line; same public API) |

SDL3 is a pinned `build.zig.zon` dependency, **not** a vendored submodule. There is no GLFW backend — this library went straight to SDL3.

## Renderer-agnostic by design

This library does windowing + input, **not** rendering — so it stays neutral about the graphics API. The window binds one renderer for its lifetime, chosen via `WindowOptions.renderer`; in every GPU case the library hands back **raw OS primitives** and links no graphics API of its own:

- **`.none`** — window + events only (headless tools, the platform-only decoupling check).
- **`.cpu`** — a software framebuffer (`SDL_GetWindowSurface`): you write 8-bit BGRA pixels on the CPU. No GPU.
- **`.vulkan`** — per-OS native handle getters + `requiredVulkanInstanceExtensions()`. *You* drive Vulkan (e.g. via the companion vulkan-stack adapter). No Vulkan types cross the API.
- **`.opengl`** — a managed GL context + `glSwapWindow`/`glGetProcAddress`/swap-interval (SDL3 `SDL_GL_*`). The GL loader lives in the *consumer*; this library ships no GL bindings.
- **`.metal`** — a `CAMetalLayer` via `getCocoaHandle`. *You* drive Metal (or MoltenVK). macOS / iOS.
- **`.directx`** — the `HWND` via `getWin32Handle`. *You* make the D3D11/12 device + swapchain. Windows.

Because no backend or graphics-API type crosses the public boundary, a consumer can migrate **between GPU APIs in stages** — and the library can later swap SDL3 for a native backend — with zero consumer-API changes. See [`mission.md`](mission.md).

## Releases

How a release happens, so that open branches do not conflict on the bookkeeping files:

- **Issue branches** (`issue-<n>-<slug>`) change code, tests, and docs, and add one changelog fragment, `changes/issue-<n>.md` (see [`changes/README.md`](../changes/README.md)). They do not edit this roadmap, `CHANGELOG.md`, the statuses in `issues.md`, or `.version` in `build.zig.zon`. Each fragment is a file of its own, so two open branches never edit the same line.
- **Bookkeeping branches** make those edits, one at a time: `release-vX.Y.Z` when a milestone's issues have merged, or `bookkeeping-<yyyy-mm-dd>` for planning between releases (new issues, re-scoped milestones). A release branch moves the fragments into a `## vX.Y.Z (yyyy-mm-dd)` section of `CHANGELOG.md` with `devops-tools changelog-fragments --settings-file devops-tools.toml release --section-title "vX.Y.Z (yyyy-mm-dd)"` ([devops_tools](https://github.com/SETA1609/devops_tools)), marks the milestone released below, sets the issues it closes to `done`, and sets `.version`.
- **One minor release per milestone.** After the release branch merges, the maintainer tags its merge commit `vX.Y.0` on `main` and pushes the tag. A patch release `vX.Y.Z` only carries fixes for a released minor. Tags are never moved or deleted.
- **Consumers** pin a tagged commit (commit and content hash) and name the tag in a comment.
- Milestones marked "shipped, untagged" came before the first tag; pin a tagged release instead.

## Version milestones

**Status:** `released vX.Y.Z` = tagged on `main` · `shipped, untagged` = on `main` before tagging began · `next` = the milestone being worked on · `planned` = not started. The **Steps** column lists the work in each milestone (☑ done, ☐ open); only a bookkeeping branch changes it. House rule for every step: a gated test-driven session (failing tests first, then the code), one atomic commit per group, and the platform-only `nm` gate (zero `vk*`/`VK_` symbols) stays green. **v1.0.0 = all SDL3-backed features done and frozen; the native per-operating-system backends are the post-1.0 (v1.x) line.** Fuller detail: [`completion-plan.md`](completion-plan.md).

| Version | Features | Steps | Status |
| --- | --- | --- | --- |
| **v0.1.0** | Foundation — repository + package manifest. | ☑ **.1** repo scaffold + MIT license + `.clang-format`. ☑ **.2** `build.zig.zon` package manifest. | shipped, untagged |
| **v0.2.0** | Foundation — the libs-first build shell. | ☑ **.1** `build.zig`: expose the `platform` **module** + the static-lib **artifact**. ☑ **.2** link **SDL3** via the pinned `castholm/SDL` dependency. | shipped, untagged |
| **v0.3.0** | Foundation — the public data types. | ☑ **.1** common types — `Event`/`KeyCode`/`WindowOptions`/`Renderer`/`ActionId`/`Capabilities`. ☑ **.2** enum value maps + error-set notes. | shipped, untagged |
| **v0.4.0** | Foundation — the declared API surface. | ☑ **.1** the full documented public API surface, panic-on-call (`init`/`Window`/events/actions/handle getters all declared so consumers can compile against it). | shipped, untagged |
| **v0.5.0** | Foundation — the test & CI scaffold. | ☑ **.1** gated red→green TDD suite + harness (`src/tests/tdd/`). ☑ **.2** contract `api_test.zig` (enum values / struct defaults / layout). ☑ **.3** CI gate — `fmt` + build + test on PRs to main. | shipped, untagged |
| **v0.6.0** | SDL3 minimal backend live: `Window` create/destroy + `size`/`setSize`/`setPosition`/`setTitle`/`scaleFactor`/`shouldClose`; event pump (`nextEvent`/`pollAllEvents`/`events`); renderer selection (`vulkan`/`opengl`/`none`); per-OS native handle getters + `requiredVulkanInstanceExtensions()`; minimal key action binding. | ☑ **.1** SDL3 lifecycle — `init` / `deinit`. ☑ **.2** time — `now` / `performanceCounter` / `performanceFrequency` / `sleep`. ☑ **.3** `Window` create/destroy + `size`/`setSize`/`setPosition`/`setTitle`/`scaleFactor`/`shouldClose`. ☑ **.4** event pump — `nextEvent` / `pollAllEvents` / `events`. ☑ **.5** renderer selection (`vulkan`/`opengl`/`none`). ☑ **.6** per-OS native handle getters + `requiredVulkanInstanceExtensions()`. ☑ **.7** minimal key action binding. ☑ **.8** GL context path via `SDL_GL_*` — `glCreateContext`/`glMakeCurrent`/`glSwapWindow`/`glSetSwapInterval`/`glGetProcAddress`/`glDestroyContext` (`13_gl_context_test.zig`). ☑ **.9** `capabilities()` (`09_capabilities` tests green). **Done** — all 9 patches landed; the GL fns + `capabilities()` are real on the SDL3 backend and their suites pass (run with a display). | shipped, untagged |
| **v0.7.0** | Action-mapped input + window/mouse control: `bindAction`/`unbindAction`/`actionPressed`/`actionJustPressed`/`actionJustReleased`; runtime window state (fullscreen/resizable/bordered + `is*`, min/max size + getters, minimize/maximize/restore/raise); mouse capture & cursor (relative mode, grab, warp, global show/hide/visible); the macOS `CAMetalLayer` getter. | ☑ **.1** action binding + state — `bindAction`/`unbindAction`/`actionPressed`/`actionJustPressed`/`actionJustReleased`. ☑ **.2** runtime window state — `setFullscreen`/`setResizable`/`setBordered` + `is*`. ☑ **.3** min/max size + getters; `minimize`/`maximize`/`restore`/`raise`. ☑ **.4** mouse capture & cursor — relative mode, grab, warp, global show/hide/visible. ☑ **.5** `windowCocoaHandle` / `getCocoaHandle` — the window's `CAMetalLayer` for a Metal surface on macOS. Input mapping contexts moved to v0.8.0; axis modifiers, injection, and loadable bindings to v0.9.0. | **first tag: `v0.7.0`**, cut on the merge of `release-v0.7.0` |
| **v0.8.0** | **Input contexts and application paths** — a menu context stops gameplay actions; per-user data and cache directories. | ☐ **.1** Input Mapping Contexts — `pushContext`/`popContext`/`replaceTopContext`/`activeContext`/`isContextActive` (Issue 1; un-skips most of `08_context`). ☐ **.2** filesystem paths `applicationDataDirectory`/`applicationCacheDirectory` (`SDL_GetPrefPath`/`GetBasePath`; Issue 2). **Minor done when** both have passing tests on Linux and Windows. | next |
| **v0.9.0** | **Input depth** — analog values, synthetic input, bindings from a file. | ☐ **.1** axis modifiers behind `actionValue` (deadzone/smooth/scale/invert). ☐ **.2** synthetic injection (`injectAction`). ☐ **.3** TOML-loadable bindings (TOML: Tom's Obvious Minimal Language, a configuration file format) *(decision: small dependency vs. hand-rolled parser)*. **Minor done when** the ~26 skipped input tests are green. | planned |
| **v0.10.0** | Device and input/output breadth: gamepad device API (Steam Input mapping) + rumble, sensor (gyroscope / inertial measurement unit), haptic, clipboard, power info, input method editor (IME) / text input. | ☐ **.1** `openWithSystemDefault` (`SDL_OpenURL`). ☐ **.2** clipboard get/set (Issue 3). ☐ **.3** input method editor / text input (`Window.startTextInput`/`stopTextInput`/`textInputActive`). ☐ **.4** gamepad device open/enumerate/close. ☐ **.5** gamepad rumble + connect/disconnect lifecycle. ☐ **.6** sensor (gyroscope / inertial measurement unit). ☐ **.7** haptic (trigger motors). ☐ **.8** power info (`SDL_GetPowerInfo`). | planned |
| **v0.11.0** | Remaining renderer paths — completes the `WindowOptions.renderer` set begun at v0.6 (`vulkan`/`opengl`/`none`): the `.cpu` software framebuffer plus the native-API hand-offs `.metal` and `.directx`. | ☐ **.1** `.cpu` software framebuffer — `windowPixels` / `presentPixels` over `SDL_GetWindowSurface`/`SDL_UpdateWindowSurface` (`18_cpu_test.zig`). ☐ **.2** `.directx` — `getWin32Handle` HWND hand-off + doc the D3D11/12 device recipe (Windows). ☐ **.3** `.metal` — `SDL_WINDOW_METAL` (macOS, contributor-led; `getCocoaHandle` → `CAMetalLayer` shipped in v0.7.0). | planned |
| **v0.12.0** | Default audio backend (`SDL_AudioStream`). | ☐ **.1** `SDL_AudioStream` — open device. ☐ **.2** queue / stream PCM. ☐ **.3** load WAV *(decision: add mp3 decoder vs. PCM/WAV-only for 1.0)*. | planned |
| **v1.0.0** | **All SDL3-backed features implemented & frozen** — every renderer path + device/IO surface validated across the target OSes; capability flags complete; API frozen. | ☐ **.1** validate every renderer path + native-handle getter on each OS (Linux X11/Wayland, Windows, Android; macOS contributor-led). ☐ **.2** CI matrix: Linux X11 + Wayland (headless compositor), Windows, Android build. ☐ **.3** wire the platform-only `nm` gate (zero `vk*`) as a **hard CI gate** + complete capability-flag divergence docs. ☐ **.4** pin `castholm/SDL` to a released tag; **freeze the API** → tag **v1.0.0**. | planned |

Critical path: v0.8 → v0.9 → v0.10 → (v0.11, v0.12 in parallel) → v1.0. v0.1–v0.5 are the shipped foundation (build/API/test scaffold) the SDL3 backend was built on. Versions after v0.8.0 may resequence as consumer needs firm up.

## Beyond v1.0.0 — native per-OS backends

After the SDL3-backed API is frozen at v1.0.0, the **v1.x** line implements **native backends per OS** behind the *same* public API — no SDL3, no consumer-API change:

| Backend | API used | Notes |
| --- | --- | --- |
| X11 | Xlib / XCB | Linux |
| Wayland | `libwayland` + xdg-shell | Linux |
| Win32 | the Windows API | Windows |
| Android | the NDK (`NativeActivity` / `ANativeWindow`) | Android |
| Cocoa | AppKit + `CAMetalLayer` | macOS / iOS (contributor-led) |

The four design rules below are what make this a backend swap rather than a rewrite: no backend type ever crossed the public API, so the consumer never notices which backend is underneath. Contributor PRs for individual native backends are welcome before then ([CONTRIBUTING](../CONTRIBUTING.md)); the `backend/native/` slot is retained as build-time scaffolding.

## Design rules (non-negotiable)

The four rules that keep the SDL3 → native backend swap cheap:

1. **Design the API to the consumer's needs, not SDL3's idioms** — no `SDL_*` types or callback registration cross the public API.
2. **Per-OS native handle getters return raw primitives** — no shared type with any renderer library.
3. **Pick canonical behavior; document divergence honestly** via capability flags.
4. **Integration tests run against every supported backend** (today: SDL3; the native per-OS backends as they land post-1.0).

## Out of scope / deferred

- **Multi-window** — single primary window for v1.0; multi-window deferred.
- **macOS as a maintainer-tested target** — SDL3 already covers macOS, but **the author has no macOS hardware to test on**, so anything macOS-specific (the `.metal` hand-off via `getCocoaHandle`, a future native Cocoa backend) is **contributor-led** and ships only with a self-tested PR ([CONTRIBUTING](../CONTRIBUTING.md)).

## See also

- Companion library: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)
- Path to 1.0: [`completion-plan.md`](completion-plan.md) · Test apps: [`validation-apps.md`](validation-apps.md)
- Deeper design rationale: the platform spec in the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) project (the engine this was built for).
