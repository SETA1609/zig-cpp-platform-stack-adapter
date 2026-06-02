# Contributing — zig-cpp-platform-stack-adapter

Thanks for your interest! This is a standalone, single-maintainer Zig library,
built **test-first**. Please read this before opening a PR so we're aligned on
scope.

## What this library is

A stable, **renderer-agnostic** Zig API for windowing + input + OS services,
backed by SDL3. See [`docs/vision.md`](docs/vision.md) and
[`docs/mission.md`](docs/mission.md). It is **not** a renderer.

## Maintainer stance — read this first

- **OpenGL is a first-class, supported path.** You can use this library with OpenGL and are *not* forced onto Vulkan. PRs that improve the GL path (`glCreateContext` / `glMakeCurrent` / `glSwapWindow` / `glGetProcAddress` / swap-interval, GL window attributes, multi-context, etc.) are welcome and will be maintained. (The maintainer's own primary consumer happens to use only the Vulkan path — but the library serves both equally.)
- **A pure-Zig native backend (X11 / Wayland / Win32 / Android) is welcome via PR — but the maintainer will not build it.** The `backend/native/` slot exists for exactly this. A contribution that is **solid and tested** (passes the full suite against *every* backend per design Rule 4, no LGPL deps) will be reviewed and merged. **Open an issue first** to align before investing the work. A single-OS slice (e.g. Wayland only) is a fine PR.

## Contributions especially welcome

- OpenGL-path improvements and fixes.
- A native backend per above — whole or one-OS-at-a-time.
- Bug fixes, more validation apps (see [`docs/validation-apps.md`](docs/validation-apps.md)), test coverage, docs / link-rot.
- macOS support — **in scope, not deferred**, but contributor-led: the maintainer won't build or test it until much later, so a clean, self-tested PR is welcome. The concrete piece is the Cocoa native-handle getter (`getCocoaHandle` → a `CAMetalLayer`), which pairs with the vulkan lib's `createMetalSurface`. See the macOS row in [`docs/completion-plan.md`](docs/completion-plan.md).

## Test-first development

The public API in `src/root.zig` is a complete set of signatures. The v0.6.0
core and the v0.7.0 window-state / mouse-capture / cursor calls have real
SDL3-backed bodies; the remaining bodies (OpenGL path, input contexts,
`capabilities()`, filesystem paths) are still `@panic("not implemented")`
stubs. Implementing the rest of the library means replacing a stub with a real
SDL3-backed body and proving it with the test that already exists for it.

### The two test steps

| Step | File(s) | What it is | When it runs |
| --- | --- | --- | --- |
| `zig build test` | `src/tests/api_test.zig` | **Contract / data tests** — enum values, struct defaults, type layout. Need no backend. | **Gates CI** — must always be green. |
| `zig build test-tdd` | `src/tests/tdd/*` | **Ordered red→green suite** — one file per function group, every test calls the real function and asserts its result. Each is **skipped** behind a `done` flag until implemented. | Off CI. The implemented groups (lifecycle, time, window, events, binding, action, Vulkan hand-off, window state, mouse — sessions `01`–`07`, `11`, `12`) have their flags flipped on and run real assertions; sessions for not-yet-implemented functions (contexts `08`, capabilities `09`, paths `10`, the GL path, and a handful of window-state sub-flags) stay skipped until their backend lands. |

Functions whose result can't be proven in-process (visual output, real hardware
input, a live GPU/GL/Vulkan surface) are **not** in the TDD suite — they are e2e
procedures in [`docs/manual-testing.md`](docs/manual-testing.md).

### The contributor workflow

1. **Pick the next unimplemented step** from the ladder below. Work in order:
   each step's functions depend on the steps above it (you can't test `events`
   before `window create` exists). A PR may implement **one or more** steps.
2. **Implement** the function(s) in `src/root.zig` (+ the SDL3 backend code).
3. **Un-skip the test**: open the matching `src/tests/tdd/NN_*_test.zig` and flip
   that function's flag in the `done` block from `false` to `true`. (That is the
   "uncomment / un-skip" — one boolean per function.)
4. **Make it green**: `zig build test-tdd -- --test-filter <fn>` until the
   function's tests pass. Then run the whole suite (`zig build test-tdd`) and
   `zig build test` to confirm nothing regressed.
5. **Tick the box** for that function in the
   [`docs/manual-testing.md`](docs/manual-testing.md) coverage checklist (and
   bump the commit hash in that heading).
6. **Open the PR.** See *Definition of done* below.

### Definition of done

A function is "done" when:

- Its `done.<fn>` flag is `true` **and every one of its TDD tests passes** — not
  skipped, not commented out. Flipping a flag without making the tests pass is
  not done.
- `zig build test` (contract) and `zig fmt --check .` stay green.
- It does not drag a GPU API it shouldn't: a `renderer = .none` build still
  shows **zero `vk*`/`VK_`** symbols (the `nm` decoupling check in
  `docs/manual-testing.md` §8).
- For functions with a manual/e2e component (a window must *appear*, a key must
  *map*), the relevant row in `docs/manual-testing.md` has been walked through
  on at least one target and ticked.

Do **not** disable, comment out, or weaken a test to make a step pass. If a test
encodes the wrong contract, fix the test in the same PR and say so — don't route
around it.

### The implementation ladder

Implement top-to-bottom. "Functions (flags)" are the booleans in that file's
`done` block.

| # | File | Functions (flags) | Milestone | Depends on |
| --- | --- | --- | --- | --- |
| 1 | `01_lifecycle_test.zig` | `init` / `deinit` (`lifecycle`) | v0.6.0 | — |
| 2 | `02_time_test.zig` | `now` · `performanceFrequency` · `performanceCounter` · `sleep` | v0.6.0 | 1 |
| 3 | `03_window_test.zig` | `create` · `destroy` · `size` · `shouldClose` · `scaleFactor` · `setSize` | v0.6.0 | 1 |
| 4 | `04_events_test.zig` | `pollAllEvents` · `nextEvent` · `events` | v0.6.0 | 1, 3 |
| 5 | `05_binding_test.zig` | `bindAction` · `unbindAction` | v0.6.0 | 1 |
| 6 | `06_vulkan_handoff_test.zig` | `requiredVulkanInstanceExtensions` · `nativeHandles` | v0.6.0 | 1, 3 |
| 7 | `07_action_test.zig` | `injectAction` · `actionPressed` · `actionJustPressed` · `actionJustReleased` · `actionValue` | v0.7.0 | 1, 4 |
| 8 | `08_context_test.zig` | `pushContext` · `popContext` · `replaceTopContext` · `activeContext` · `isContextActive` | v0.7.0 | 1 |
| 9 | `09_capabilities_test.zig` | `capabilities` | v0.7.0 | 1 |
| 10 | `10_paths_test.zig` | `applicationDataDirectory` · `applicationCacheDirectory` | v0.8.0 | 1 |

Within a file, a test that exercises more than one function gates on all of them
(e.g. `setSize` tests also need `size` + `scaleFactor`), so flip the flags a test
names before expecting it to run. Only flip a step's flags once **all earlier
ladder steps are implemented** — later steps assume the earlier ones work.

## Out of scope

- Rendering, or GL/Vulkan *bindings* / draw-call wrappers — the library provides the prerequisites, not the drawing.
- Leaking backend idioms into the public API (no `SDL_*` / `GLFW*` types across the boundary — design Rule 1).
- Making the windowing and any renderer library share a type — they stay fully decoupled (design Rule 2).

## The four design rules a PR must uphold

1. Design the API to the consumer's needs, not the backend's idioms.
2. Per-OS native handle getters return raw primitives; no shared type with a renderer library.
3. Pick canonical behavior; document divergence honestly via capability flags.
4. **Integration tests run against every supported backend.** A new backend must pass the *existing* suite — it doesn't get to ship a reduced one.

## Using C and C++

You are free to write backend/bridge code in **C or C++** (e.g. SDL3 glue,
platform-specific shims) — but it must stay **behind the Zig API**:

- **Bridge everything to Zig.** No C/C++ type ever crosses the public surface in
  `src/root.zig` — the API is Zig types only (design Rule 1: no `SDL_*` type
  leaks out). Add a `noexcept` `extern "C"` bridge and **catch before crossing
  the C ABI**; a C++ exception must never propagate into Zig.
- **C++ style: Google conventions, max C++23.** Already encoded in
  [`.clang-format`](.clang-format) (`BasedOnStyle: Google`, `Standard: c++23`).
  Run `clang-format` on any C/C++ you add; keep `zig fmt --check .` green for the
  Zig side. Do not use language features past C++23.
- **Smart pointers first, manual pointers later — in separate PRs.** Write the
  initial implementation with RAII / smart pointers (`std::unique_ptr`,
  `std::shared_ptr`) so ownership is obviously correct, and land that. If
  profiling later shows a smart-pointer is a real cost, move it to a manual /
  raw pointer **in a follow-up PR** dedicated to that optimization, with the
  measurement that justifies it. Correctness first, optimization second, never
  mixed in one PR.

## Licensing & legal

- Contributions are licensed under this repo's **MIT** license. By submitting a PR you agree to license your contribution under MIT. **No CLA required.**
- **No GPL / LGPL / AGPL dependencies — ever.** A native Linux backend must avoid `libudev` / `gettext` / etc. — read input from `/dev/input` directly or use `libxkbcommon` (MIT), not LGPL libs.
- Don't copy code from LGPL/GPL projects. Reimplement from understanding.

## Dev setup

- **Zig 0.16+** (the build uses post-0.16 APIs).
- `zig build` — build; `zig build test` — the contract suite; `zig build test-tdd` — the red→green TDD suite (needs a display server).
- Lint before pushing: `zig fmt --check .` and (for any C/C++) `clang-format --dry-run -Werror`. CI runs these.

## Commits & PRs

- **Conventional Commits** (`feat:` / `fix:` / `docs:` / `chore:` / `ci:` / `test:`), atomic — one concern per commit, subject ≤ 72 chars.
- Small fixes: open a PR directly. Larger work (a backend, an API addition): **open an issue first.**
- A PR that adds functionality should add a validation app or a test for it.
