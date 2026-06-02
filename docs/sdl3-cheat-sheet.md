# SDL3 cheat sheet

> What SDL3 is, how it works, and how **this adapter maps onto it** — a quick
> reference for working on the SDL3 backend (`src/backend/sdl3.zig`). For the
> Zig↔C/C++ language mechanics see [`cheat_sheet.md`](cheat_sheet.md); this file
> is about SDL itself.
>
> Deep dives link to the official **[SDL3 wiki](https://wiki.libsdl.org/SDL3/)**.

## What SDL3 is

[SDL](https://www.libsdl.org/) (Simple DirectMedia Layer) is a cross-platform C
library that abstracts the OS-specific bits of a desktop/mobile app: creating
windows, reading keyboard/mouse/gamepad input, timers, audio, clipboard, and
the hand-off to a GPU API (Vulkan / OpenGL / Metal / D3D). **SDL3** is the
current major version (zlib-licensed). It's what this library uses as its
backend — but no `SDL_*` type crosses our public API (design Rule 1), so SDL is
an implementation detail you only see in `src/backend/`.

We consume SDL3 via [`castholm/SDL`](https://github.com/castholm/SDL), which
packages SDL's C sources for the Zig build system and exposes the `SDL3`
artifact (compiled once, linked into our static lib).

- Migration from SDL2 (lots of renames/semantics): [SDL3 migration guide](https://wiki.libsdl.org/SDL3/README/migration)
- Full function index: [SDL3 API by category](https://wiki.libsdl.org/SDL3/APIByCategory)

## The big picture — how an SDL app is shaped

```
SDL_Init(flags)                     // bring up subsystems (video/audio/gamepad)
  └─ SDL_CreateWindow(...)          // one or more windows
       loop:
         SDL_PollEvent(&e)          // drain the OS event queue into SDL_Event
         ... react, render ...
SDL_Quit()                          // tear everything down
```

SDL owns a global event queue fed by the OS; you pump it once per frame and
SDL hands you normalized `SDL_Event`s. State APIs (`SDL_GetKeyboardState`,
`SDL_GetMouseState`) give you *current* held state, separate from the *event*
stream. That two-track model (events for transitions, state for "is it held
now") is exactly what our action layer uses.

## Core concepts (and the SDL3 calls)

| Area | Key SDL3 calls | Notes |
| --- | --- | --- |
| **Lifecycle** | [`SDL_Init`](https://wiki.libsdl.org/SDL3/SDL_Init) / [`SDL_Quit`](https://wiki.libsdl.org/SDL3/SDL_Quit) | Flags: `SDL_INIT_VIDEO` / `_GAMEPAD` / `_AUDIO`. Video subsystem needs a display server (or a dummy driver — see gotchas). |
| **Window** | [`SDL_CreateWindow`](https://wiki.libsdl.org/SDL3/SDL_CreateWindow), [`SDL_DestroyWindow`](https://wiki.libsdl.org/SDL3/SDL_DestroyWindow), [window flags](https://wiki.libsdl.org/SDL3/SDL_WindowFlags) | `SDL_WINDOW_VULKAN` / `_OPENGL` / `_RESIZABLE` / `_HIGH_PIXEL_DENSITY` / `_HIDDEN` … |
| **Sizing** | [`SDL_GetWindowSizeInPixels`](https://wiki.libsdl.org/SDL3/SDL_GetWindowSizeInPixels), [`SDL_SetWindowSize`](https://wiki.libsdl.org/SDL3/SDL_SetWindowSize), [`SDL_SyncWindow`](https://wiki.libsdl.org/SDL3/SDL_SyncWindow), [`SDL_GetWindowDisplayScale`](https://wiki.libsdl.org/SDL3/SDL_GetWindowDisplayScale) | "Pixels" vs "window coordinates" differ on HiDPI — see gotchas. |
| **Events** | [`SDL_PollEvent`](https://wiki.libsdl.org/SDL3/SDL_PollEvent), [`SDL_Event`](https://wiki.libsdl.org/SDL3/SDL_Event), [`SDL_EventType`](https://wiki.libsdl.org/SDL3/SDL_EventType) | One tagged union; `e.type` selects the active payload (`e.key`, `e.motion`, `e.window`, …). |
| **Keyboard** | [`SDL_GetKeyboardState`](https://wiki.libsdl.org/SDL3/SDL_GetKeyboardState), [`SDL_Scancode`](https://wiki.libsdl.org/SDL3/SDL_Scancode) | **Scancode** = physical key position (layout-independent); **keycode** = the character it produces. We map scancodes. |
| **Mouse** | [`SDL_GetMouseState`](https://wiki.libsdl.org/SDL3/SDL_GetMouseState), [button masks](https://wiki.libsdl.org/SDL3/SDL_BUTTON_MASK) | |
| **Time** | [`SDL_GetTicksNS`](https://wiki.libsdl.org/SDL3/SDL_GetTicksNS), [`SDL_GetPerformanceCounter`](https://wiki.libsdl.org/SDL3/SDL_GetPerformanceCounter), [`SDL_GetPerformanceFrequency`](https://wiki.libsdl.org/SDL3/SDL_GetPerformanceFrequency), [`SDL_DelayNS`](https://wiki.libsdl.org/SDL3/SDL_DelayNS) | Monotonic ns + a high-res perf counter. |
| **Properties** | [`SDL_GetWindowProperties`](https://wiki.libsdl.org/SDL3/SDL_GetWindowProperties), [`SDL_GetPointerProperty`](https://wiki.libsdl.org/SDL3/SDL_GetPointerProperty) | The SDL3 way to reach native handles (X11 display/XID, Wayland display/surface, Win32 HWND/HINSTANCE) — see [window properties](https://wiki.libsdl.org/SDL3/SDL_GetWindowProperties). |
| **Vulkan** | [`SDL_Vulkan_GetInstanceExtensions`](https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetInstanceExtensions), [`SDL_Vulkan_LoadLibrary`](https://wiki.libsdl.org/SDL3/SDL_Vulkan_LoadLibrary) | We return the extension list; the surface is created by the **vulkan** adapter from the native handle (no `SDL_Vulkan_CreateSurface` — keeps the libs decoupled). |
| **OpenGL** | [`SDL_GL_CreateContext`](https://wiki.libsdl.org/SDL3/SDL_GL_CreateContext), [`SDL_GL_GetProcAddress`](https://wiki.libsdl.org/SDL3/SDL_GL_GetProcAddress), [`SDL_GL_SwapWindow`](https://wiki.libsdl.org/SDL3/SDL_GL_SwapWindow) | *(our GL path is still stubbed — v0.6.0)* |

## How this adapter maps onto SDL3

`src/backend/sdl3.zig` is the only file that calls SDL. The public API → SDL3 mapping:

| Our API | SDL3 |
| --- | --- |
| `init(opts)` / `deinit()` | `SDL_Init(flags)` / `SDL_Quit()` |
| `Window.create(opts)` | `SDL_CreateWindow` (+ `SDL_SetPointerProperty` to stash our per-window state) |
| `Window.size()` / `setSize()` | `SDL_GetWindowSizeInPixels` / `SDL_SetWindowSize` + `SDL_SyncWindow` |
| `Window.scaleFactor()` | `SDL_GetWindowDisplayScale` |
| `pollAllEvents()` | `SDL_PumpEvents` loop over `SDL_PollEvent` → translate into our `Event` SoA + queue |
| `bindAction` + `actionPressed` | bindings resolved each frame against `SDL_GetKeyboardState` / `SDL_GetMouseState` |
| `now()` / `performanceCounter()` / `sleep()` | `SDL_GetTicksNS` / `SDL_GetPerformanceCounter` / `SDL_DelayNS` |
| `getX11Handle` / `getWaylandHandle` / … | `SDL_GetWindowProperties` + the `SDL_PROP_WINDOW_*` keys |
| `requiredVulkanInstanceExtensions()` | `SDL_Vulkan_LoadLibrary(null)` + `SDL_Vulkan_GetInstanceExtensions` |

## Gotchas (learned the hard way)

- **SDL3 returns `bool`, not `0`-on-success.** Most SDL3 functions return `true`
  on success / `false` on failure (SDL2 returned `int`). `if (!c.SDL_Init(...)) return error...`.
- **Window resize is asynchronous / WM-mediated.** `SDL_SetWindowSize` only
  *requests* a size; the WM applies it later. Call [`SDL_SyncWindow`](https://wiki.libsdl.org/SDL3/SDL_SyncWindow)
  to block until it's applied (times out on a tiling WM that ignores the request).
- **Pixels ≠ window coordinates on HiDPI.** With `SDL_WINDOW_HIGH_PIXEL_DENSITY`,
  `SDL_SetWindowSize` is in *window coordinates* but `SDL_GetWindowSizeInPixels`
  returns *pixels* = coords × `SDL_GetWindowDisplayScale`. Equal only at scale 1.0.
- **Video init needs a display.** `SDL_Init(SDL_INIT_VIDEO)` fails with no
  X11/Wayland session. For headless CI, set the env `SDL_VIDEODRIVER=dummy` (or
  `offscreen`) — but note `dummy` has no Vulkan/native handles.
- **Native handles live in window properties (SDL3), not getters (SDL2).**
  `SDL_GetWindowProperties(win)` → `SDL_GetPointerProperty(props, SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null)` etc.
- **`@cImport` enum-constant signedness:** SDL's C enum *types* import as `c_uint`
  but their *constants* as `c_int` — mixed arithmetic needs an explicit `@intCast`
  (bit us in the scancode mapping).
- **Vulkan extensions need the loader first.** `SDL_Vulkan_GetInstanceExtensions`
  requires either a `SDL_WINDOW_VULKAN` window or a prior `SDL_Vulkan_LoadLibrary`.

## Deep-dive links

- [SDL3 wiki home](https://wiki.libsdl.org/SDL3/) · [API by category](https://wiki.libsdl.org/SDL3/APIByCategory) · [FAQ](https://wiki.libsdl.org/SDL3/FAQ)
- [SDL2 → SDL3 migration guide](https://wiki.libsdl.org/SDL3/README/migration) — semantics that changed
- [Properties (`SDL_PropertiesID`)](https://wiki.libsdl.org/SDL3/CategoryProperties) — the native-handle mechanism
- [Vulkan support](https://wiki.libsdl.org/SDL3/CategoryVulkan) · [Events](https://wiki.libsdl.org/SDL3/CategoryEvents) · [Video/Window](https://wiki.libsdl.org/SDL3/CategoryVideo)
- [`castholm/SDL`](https://github.com/castholm/SDL) — how SDL3 is packaged for the Zig build system
- Companion: [`docs/api.md`](api.md) (our surface) · [`docs/enum-values.md`](enum-values.md) (our stable enum maps)
