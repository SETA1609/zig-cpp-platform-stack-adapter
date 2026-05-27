# Validation apps — zig-cpp-platform-stack-adapter

> Small standalone apps that consume this adapter via `build.zig.zon` **exactly the way the engine will** — to validate the public Zig API (and, for paired apps, the engine's `surface.zig` bridge) *before* the engine exists. Each is a throwaway project in its own directory/repo, not part of the engine.
>
> **Complementary to the reference-C++-host track** ([zVoxRealms `external-libs-catalog.md` § 5.5](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/external-libs-catalog.md)). That track drops the adapter into a reference C++ host (a voxel engine) to validate the *C ABI + build wiring* against real workloads. A C++ host uses its own windowing/GL stack, so it **cannot** exercise *this adapter's* public Zig API or the surface bridge — these mini-apps are the only thing that does.
>
> Roadmap + version gates: [`ROADMAP.md`](ROADMAP.md). Sprint: [`sprint.md`](sprint.md).

## Completion checklist

Mark `[x]` only when the app **builds and runs correctly** — not merely compiles. `[~]` = in progress.

- [ ] **Event logger** — window + every `Event` + `actionPressed` to stdout · *platform v0.6.0*
- [ ] **`nm` decoupling check** — Event-logger binary shows **zero `vk*` symbols** · *platform v0.6.0*
- [ ] **Reactive clear-color** — bg color follows mouse / cycles on keypress (paired with vulkan-stack) · *platform v0.6.0 + vulkan v0.2.0*
- [ ] **Snake** — grid of quads, fixed-timestep loop, action input (paired) · *platform v0.6.0 + vulkan v0.3.0*
- [ ] **Tetris** — pause menu pushes `ui_menu` context, masking gameplay actions (paired) · *platform v0.7.0 + vulkan v0.3.0*
- [ ] **Pong (2-player, gamepads)** — two gamepads + analog axes with modifiers (paired) · *platform v0.8.0 + vulkan v0.3.0*
- [ ] **Gamepad tester** — axes/buttons + deadzone/smooth/scale/invert printout · *platform v0.8.0*

## The ladder — what each app validates

| App | Needs | Validates (for this adapter) | Paired? |
| --- | --- | --- | --- |
| **Event logger** | platform v0.6.0 | Window lifecycle (`create`/`destroy`/`shouldClose`), the `SDL_PollEvent → Event` union mapping, minimal action binding. **Runs first** — before any Vulkan exists. | no |
| **Reactive clear-color** | + vulkan v0.2.0 | The native-handle getters + `requiredVulkanInstanceExtensions()` feed the engine `surface.zig` bridge → `createX11Surface` etc. **The key proof the decoupled two-adapter pairing works end to end.** Also swapchain-recreate on `.resize`. | yes |
| **Snake** | + vulkan v0.3.0 | Window + input + `now()` timing under a real fixed-timestep game loop. | yes |
| **Tetris** | + vulkan v0.3.0 | **Input Mapping Contexts** — push `ui_menu` on pause (masks gameplay actions), pop on resume. The one app that proves the context stack. (needs platform v0.7.0) | yes |
| **Pong (2-player)** | + vulkan v0.3.0 | Multi-gamepad; analog axis with deadzone/smooth/scale/invert. Stresses the input layer specifically. (needs platform v0.8.0) | yes |
| **Gamepad tester** | platform v0.8.0 | Gamepad enumeration + hotplug events + axis-modifier math, printed — no rendering. | no |

## Required decoupling check (`nm`)

The architecture rests on this adapter dragging **no Vulkan**. After building the **Event logger**:

```sh
nm <event-logger-binary> | grep -i 'vk[A-Z]\|VK_'   # must print NOTHING
```

A non-empty result means a Vulkan symbol leaked across the boundary — fix it now, in a ~200-line app, not in the engine.

## Discipline

Per [zVoxRealms `docs/guard.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/guard.md): **you write these apps by hand** (learning project). They live outside the engine tree and depend on this adapter (and, for paired apps, the [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)) via pinned `build.zig.zon` entries — the same consumption pattern the engine uses. The "spinning textured cube" is deliberately **not** on this list: that's the engine's own Phase 1 milestone, so these stay 2D (quads + ortho).
