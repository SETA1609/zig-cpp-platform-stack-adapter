# Validation apps — zig-cpp-platform-stack-adapter

> Small standalone apps that consume this library via `build.zig.zon` **the way a real consumer will** — to exercise the public Zig API (and, for paired apps, a consumer's surface-creation bridge). Each is a throwaway project in its own directory, not part of the library.
>
> These complement testing the library inside a larger host application: a C++ host (or any app using its own windowing/GL stack) **can't** exercise *this library's* Zig API or the renderer-handoff path — these mini-apps are the only thing that does.
>
> Version gates: [`ROADMAP.md`](ROADMAP.md). Milestone plan: [`sprint.md`](sprint.md).

## Completion checklist

Mark `[x]` only when the app **builds and runs correctly** — not merely compiles. `[~]` = in progress.

- [ ] **Event logger** — window + every `Event` + `actionJustPressed(.menu_pause)` to stdout · *v0.6.0* — [details](#event-logger-v060)
- [ ] **`nm` decoupling check** — Event-logger binary shows **zero `vk*` / `VK_` symbols** · *v0.6.0*
- [ ] **GL clear-color** — `renderer=.opengl`, GL context + `glClear`/`glSwapWindow`, no Vulkan · *v0.6.0*
- [ ] **Vulkan clear-color** — `renderer=.vulkan` → surface → swapchain clear (pair with a Vulkan renderer) · *v0.6.0 + a Vulkan renderer*
- [ ] **Snake** — grid of quads, fixed-timestep loop, action input · *v0.6.0 + a renderer*
- [ ] **Tetris** — pause menu pushes `ui_menu` context, masking gameplay actions · *v0.7.0 + a renderer*
- [ ] **Pong (2-player, gamepads)** — two gamepads + analog axes with modifiers · *v0.8.0 + a renderer*
- [ ] **Gamepad tester** — axes/buttons + deadzone/smooth/scale/invert printout · *v0.8.0*

## The ladder — what each app validates

| App | Needs | Validates | Renderer? |
| --- | --- | --- | --- |
| **Event logger** | v0.6.0 | Window lifecycle (`create`/`destroy`/`shouldClose`), the `SDL_PollEvent → Event` mapping, minimal action binding. **Runs first** — no GPU API involved. | none |
| **GL clear-color** | v0.6.0 | The **OpenGL path**: `renderer = .opengl` → `glCreateContext` → load GL via `glGetProcAddress` → `glClear` + `glSwapWindow`. Proves the library serves OpenGL with zero Vulkan involvement. | OpenGL |
| **Vulkan clear-color** | v0.6.0 | The **Vulkan path**: native-handle getters + `requiredVulkanInstanceExtensions()` feed a surface creator → swapchain clear → present; swapchain-recreate on `.resize`. Run it beside **GL clear-color** against the *same* library build to prove renderer-agnosticism. | Vulkan |
| **Snake** | v0.6.0 | Window + input + `now()` timing under a real fixed-timestep game loop. | any |
| **Tetris** | v0.7.0 | **Input Mapping Contexts** — push `ui_menu` on pause (masks gameplay actions), pop on resume. The one app that proves the context stack. | any |
| **Pong (2-player)** | v0.8.0 | Multi-gamepad; analog axis with deadzone/smooth/scale/invert. Stresses the input layer. | any |
| **Gamepad tester** | v0.8.0 | Gamepad enumeration + hotplug events + axis-modifier math, printed — no rendering. | none |

## What each app needs, version by version

### Event logger (v0.6.0) <a id="event-logger-v060"></a>

> Rung 0 of the [companion examples-repo ladder](https://github.com/SETA1609/zig-stack-adapter-examples/blob/main/docs/ladder.md). Platform-only — **imports no Vulkan**. Carries the `nm` decoupling check.

**API surface this app exercises (must all be real, not panic-on-call, by `v0.6.0`):**

| API | Sprint item | Used as |
| --- | --- | --- |
| `init(InitOptions) !void` / `deinit()` | P1.5 | startup / shutdown |
| `Window.create(WindowOptions) !*Window` with `.renderer = .none` | P1.5 | open the window with **no** GPU API |
| `Window.destroy()` / `Window.shouldClose()` | P1.5 | the main-loop predicate + clean teardown |
| `pollAllEvents()` / `nextEvent() ?Event` | P1.5 | drain the event queue once per frame |
| `Event` union + payloads (`key`, `mouse_button`, `mouse_motion`, `mouse_scroll`, `resize`, `focus`, `close`) | P1.3 + P1.5 | print one line per event |
| `bindAction(.menu_pause, .{ .key = .escape })` | P1.7 | wire ESC to the quit action |
| `actionJustPressed(.menu_pause) bool` | P1.7 | edge-triggered quit (not on hold/repeat) |

The app does **not** use: `getX11Handle`/`getWaylandHandle`/`getWin32Handle`, `requiredVulkanInstanceExtensions()`, the GL context APIs, `actionValue`, contexts, injection, gamepad/sensor/text-input, or filesystem paths. Those are for later rungs.

**Definition of done from the lib's side:**

- A consumer that imports `@import("platform")` and links the static `platform` artifact can write the app described in [`../../../../examples/event-logger/README.md`](../../../zig-stack-adapter-examples/examples/event-logger/README.md) (companion repo) using only the table above — **no SDL types**, **no Vulkan types**, **no GL types** appear in the consumer's code.
- The resulting binary's `nm` output has **zero `vk*` / `VK_` symbols** (the library drags no Vulkan).
- The window opens on `x86_64-linux-gnu` (X11 *and* Wayland sessions) and `x86_64-windows-gnu`. `.close` events are delivered when the WM × button is pressed. ESC fires `menu_pause` exactly once per press (edge, not level).

If the consumer can write event-logger without reaching past the table above, the v0.6.0 API surface is correctly shaped. If they need to, the API is missing something — fix it in the lib, in v0.6.0, before tagging.

## Required decoupling check (`nm`)

This library must drag **no GPU API** into a binary that doesn't ask for one. After building the **Event logger** (`renderer = .none`):

```sh
nm <event-logger-binary> | grep -i 'vk[A-Z]\|VK_'   # must print NOTHING
```

A non-empty result means a Vulkan symbol leaked across the boundary — fix it now, in a ~200-line app.

## Notes

- Apps depend on this library (and, for paired apps, a Vulkan renderer such as the companion [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)) via pinned `build.zig.zon` entries — the same pattern a real consumer uses.
- Tests stay 2D (quads + ortho) on purpose — they exercise *this library*, not a full 3D renderer.
