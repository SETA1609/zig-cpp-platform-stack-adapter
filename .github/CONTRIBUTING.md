# Contributing — zig-cpp-platform-stack-adapter

Thanks for your interest! This is a standalone, single-maintainer Zig library. Please read this before opening a PR so we're aligned on scope.

## What this library is

A stable, **renderer-agnostic** Zig API for windowing + input + OS services, backed by SDL3. See [`docs/vision.md`](../docs/vision.md) and [`docs/mission.md`](../docs/mission.md). It is **not** a renderer.

## Maintainer stance — read this first

- **OpenGL is a first-class, supported path.** You can use this library with OpenGL and are *not* forced onto Vulkan. PRs that improve the GL path (`glCreateContext` / `glMakeCurrent` / `glSwapWindow` / `glGetProcAddress` / swap-interval, GL window attributes, multi-context, etc.) are welcome and will be maintained. (The maintainer's own primary consumer happens to use only the Vulkan path — but the library serves both equally.)
- **A pure-Zig native backend (X11 / Wayland / Win32 / Android) is welcome via PR — but the maintainer will not build it.** The `backend/native/` slot exists for exactly this. A contribution that is **solid and tested** (passes the full suite against *every* backend per design Rule 4, no LGPL deps) will be reviewed and merged. **Open an issue first** to align before investing the work. A single-OS slice (e.g. Wayland only) is a fine PR.

## Contributions especially welcome

- OpenGL-path improvements and fixes.
- A native backend per above — whole or one-OS-at-a-time.
- Bug fixes, more validation apps (see [`docs/validation-apps.md`](../docs/validation-apps.md)), test coverage, docs / link-rot.
- macOS support (deferred; a clean PR is welcome).

## Out of scope

- Rendering, or GL/Vulkan *bindings* / draw-call wrappers — the library provides the prerequisites, not the drawing.
- Leaking backend idioms into the public API (no `SDL_*` / `GLFW*` types across the boundary — design Rule 1).
- Making the windowing and any renderer library share a type — they stay fully decoupled (design Rule 2).

## The four design rules a PR must uphold

1. Design the API to the consumer's needs, not the backend's idioms.
2. Per-OS native handle getters return raw primitives; no shared type with a renderer library.
3. Pick canonical behavior; document divergence honestly via capability flags.
4. **Integration tests run against every supported backend.** A new backend must pass the *existing* suite — it doesn't get to ship a reduced one.

## Licensing & legal

- Contributions are licensed under this repo's **MIT** license. By submitting a PR you agree to license your contribution under MIT. **No CLA required.**
- **No GPL / LGPL / AGPL dependencies — ever.** A native Linux backend must avoid `libudev` / `gettext` / etc. — read input from `/dev/input` directly or use `libxkbcommon` (MIT), not LGPL libs.
- Don't copy code from LGPL/GPL projects. Reimplement from understanding.

## Dev setup

- **Zig 0.16+** (the build uses post-0.16 APIs).
- `zig build` — build; `zig build test` — run the suite.
- Lint before pushing: `zig fmt --check .` and (for any C/C++) `clang-format --dry-run -Werror`. CI runs these.

## Commits & PRs

- **Conventional Commits** (`feat:` / `fix:` / `docs:` / `chore:` / `ci:` / `test:`), atomic — one concern per commit, subject ≤ 72 chars.
- Small fixes: open a PR directly. Larger work (a backend, an API addition): **open an issue first.**
- A PR that adds functionality should add a validation app or a test for it.
