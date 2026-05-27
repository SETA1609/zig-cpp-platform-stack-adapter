# Vision — zig-cpp-platform-stack-adapter

> One stable, **renderer-agnostic** platform API — window, events, action-mapped input, time, file I/O, native handles — that outlives the backend behind it.

## The north star

A consumer imports `platform` and never sees a backend. The backend is **SDL3** today; it could be a native Zig backend or a future SDL tomorrow. When it changes, **consumer source changes nowhere** — that is the reason this exists as a separate, versioned library.

## Renderer-agnostic — serve Vulkan *and* OpenGL *and* headless

This library does **windowing + input + OS services**, not rendering. It therefore stays neutral about *which* GPU API the consumer draws with. Three independent paths hang off the same window:

| Path | What the library provides | Consumer |
| --- | --- | --- |
| **Vulkan** | per-OS native handle getters + `requiredVulkanInstanceExtensions()` — raw primitives, no Vulkan types | any Vulkan renderer (e.g. the companion [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)) |
| **OpenGL** | a managed GL context + `glSwapWindow` + `glGetProcAddress` + swap-interval | any GL renderer (loader lives in the consumer) |
| **headless / 2D** | window + events only | tools, custom 2D |

**Why this matters concretely:** consumers are **not** forced onto Vulkan, and a renderer can be migrated **from OpenGL to Vulkan in stages** without first rewriting its windowing/input layer. Keep the GL renderer shipping while a Vulkan renderer is built against the *same* platform API, then flip when it reaches parity. The platform layer is the stable floor under that migration. (Honest limit: a single window binds to one GPU API at creation; this enables *switching* renderers in stages, not mixing GL and Vulkan in one window.)

## Reusable in isolation

A headless server, a config editor, a 2D tool, a GL app, or a Vulkan app can each consume this library alone. It drags **no GPU API** into a binary that doesn't ask for one — enforced by the `nm` decoupling check in [`validation-apps.md`](validation-apps.md).

## Non-vision (what this is deliberately not)

- A renderer, a frame graph, or a material system.
- A GL/Vulkan abstraction — it hands you the *prerequisites* for each, it does not wrap drawing.
- A mod/script ABI.

## Origin

Built for and used by the [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) engine, but designed to stand alone. See [`mission.md`](mission.md) for the concrete commitments and [`ROADMAP.md`](ROADMAP.md) for the version sequence.
