# Validation apps — zig-cpp-platform-stack-adapter

> Small standalone apps that consume this library via `build.zig.zon` **the way a real consumer will** — to exercise the public Zig API (and, for paired apps, a consumer's surface-creation bridge). Each is a throwaway project in its own directory, not part of the library.
>
> These complement testing the library inside a larger host application: a C++ host (or any app using its own windowing/GL stack) **can't** exercise *this library's* Zig API or the renderer-handoff path — these mini-apps are the only thing that does.
>
> Version gates: [`ROADMAP.md`](ROADMAP.md). Milestone plan: [`sprint.md`](sprint.md).

## Completion checklist

Mark `[x]` only when the app **builds and runs correctly** — not merely compiles. `[~]` = in progress.

- [ ] **Event logger** — window + every `Event` + `actionPressed` to stdout · *v0.6.0*
- [ ] **`nm` decoupling check** — Event-logger binary shows **zero `vk*` symbols** · *v0.6.0*
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

## Required decoupling check (`nm`)

This library must drag **no GPU API** into a binary that doesn't ask for one. After building the **Event logger** (`renderer = .none`):

```sh
nm <event-logger-binary> | grep -i 'vk[A-Z]\|VK_'   # must print NOTHING
```

A non-empty result means a Vulkan symbol leaked across the boundary — fix it now, in a ~200-line app.

## Notes

- Apps depend on this library (and, for paired apps, a Vulkan renderer such as the companion [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)) via pinned `build.zig.zon` entries — the same pattern a real consumer uses.
- Tests stay 2D (quads + ortho) on purpose — they exercise *this library*, not a full 3D renderer.
