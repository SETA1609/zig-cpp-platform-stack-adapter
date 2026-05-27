# Vision — zig-cpp-platform-stack-adapter

> One stable, **renderer-agnostic** platform API — window, events, action-mapped input, time, file I/O, native handles — that outlives the backend behind it.

## The north star

A consumer imports `platform` and never sees a backend. The backend is **SDL3** today; it could be a native Zig backend or SDL4 tomorrow. When it changes, **consumer source changes nowhere** — that is the entire reason this adapter exists as a separate, versioned sub-repo.

## Renderer-agnostic — serve Vulkan *and* OpenGL *and* headless

This adapter does **windowing + input + OS services**, not rendering. It therefore stays neutral about *which* GPU API the consumer draws with. Three independent paths hang off the same window:

| Path | What the adapter provides | Consumer |
| --- | --- | --- |
| **Vulkan** | per-OS native handle getters + `requiredVulkanInstanceExtensions()` — raw primitives, no Vulkan types | pairs with [vulkan-stack adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter) |
| **OpenGL** | a managed GL context + `glSwapWindow` + `glGetProcAddress` + swap-interval | any GL renderer (loader lives in the consumer) |
| **headless / 2D** | window + events only (or `SDL_Renderer` 2D primitives at v0.9.0) | tools, the widget kit |

**Why this matters concretely:** it lets a renderer be migrated **from OpenGL to Vulkan in stages** without first rewriting its windowing/input layer. A reference C++ host with a mature GL renderer keeps shipping on the OpenGL path while a Vulkan renderer is built up against the *same* platform API, then flips over when it reaches parity. The platform layer is the stable floor under that migration. (Honest limit — see [`mission.md`](mission.md): a single window binds to one GPU API at creation; this enables *switching* renderers in stages, not mixing GL and Vulkan in one window.)

## Reusable in isolation

A headless server, a config editor, a 2D tool, a GL app, or a Vulkan app can each consume this adapter alone. It drags **no GPU API** into a binary that doesn't ask for one — enforced by the `nm` decoupling check in [`validation-apps.md`](validation-apps.md).

## Non-vision (what this is deliberately not)

- A renderer, a frame graph, or a material system — those are engine code.
- A GL/Vulkan abstraction layer — it hands you the *prerequisites* for each, it does not wrap drawing.
- A mod/script ABI — that is a separate engine-level concern.

See [`mission.md`](mission.md) for the concrete commitments that realize this, and [`ROADMAP.md`](ROADMAP.md) for the version sequence.
