# Dependencies & language mix — zig-cpp-platform-stack-adapter

> What this library consumes, and the language split of the code **written here** (the glue) vs. **vendored** (the upstreams). These are very different numbers — see the note at the bottom.

## Consumed libraries

| Library | Upstream language | License | Role |
| --- | --- | --- | --- |
| **SDL3** (built via [`castholm/SDL`](https://github.com/castholm/SDL)) | **C** | zlib (core) | The backend — window, events, input, gamepad, sensor, haptic, clipboard, paths, power, IME, and `SDL_GL_*` / Vulkan surface prerequisites |
| [`castholm/SDL`](https://github.com/castholm/SDL) | Zig (build only) | zlib / MIT | Packages SDL3's C sources for the Zig build system; produces the `SDL3` artifact |
| *(future, not maintainer-led)* libxkbcommon etc. | C | MIT | Only if a community native backend is contributed |

No GPL/LGPL dependencies (HIDAPI inside SDL is elected under BSD-3-Clause).

## Hand-written code — language split (estimate)

| Language | Estimate | What |
| --- | --- | --- |
| **Zig** | **~97%** | `root.zig`, `common.zig`, `action_input.zig`, `native_handle.zig`, `backend/sdl3.zig`, `build.zig`, tests |
| **C** | **~3%** | at most a tiny `shim.c` if `@cImport` can't translate a specific SDL macro / inline function |
| **C++** | **~0%** | none for the SDL3 backend |

### Why ~no C++ here

SDL3 is pure **C**, and Zig consumes C natively via `@cImport` — so there is **no `extern "C"` bridge to write**. This library is effectively **pure Zig glue over a C dependency**. The `-cpp-` in the repo name follows a naming convention shared with its [companion](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter); it does *not* reflect any C++ in this adapter. C++ would only appear if a future **macOS native backend** (Objective-C++) were contributed — deferred and not maintainer-led.

## "Written" vs. "compiled"

The split above is **code authored in this repo** (a few hundred lines). If you instead measured the **compiled artifact**, it would read as overwhelmingly C — SDL3 is hundreds of thousands of lines of C that get linked in. So:

- **Authored here:** ~all Zig.
- **In the shipped binary:** mostly SDL3's C, with a thin Zig surface on top.

Estimates only — real numbers firm up as the [completion plan](completion-plan.md) is completed (the v0.6.0 core and v0.7.0 window-state/mouse layers have landed; the OpenGL path and later milestones are still ahead).
