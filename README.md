# zig-cpp-platform-stack-adapter

A meta-package adapter exposing a **stable Zig API** for the platform layer — window, events, action-mapped input, time, file I/O, and Vulkan-surface creation. The implementation backend swaps between major versions of this sub-repo without consumers changing a line of code.

**License:** [MIT](LICENSE)
**Status:** Phase 0 (Foundation) — currently a hello-world stub. Real backend wrapping starts at [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds) Phase 1.

---

## What it is

A standalone Zig package that consumers (engines, games, tools) import as a single dependency to get cross-platform windowing + input. Bundled in this single sub-repo are:

- **Public Zig API** (`src/root.zig`) — opaque `Window`, queued `Event`, action-mapped input, time, file paths, Vulkan-surface creation
- **One backend implementation at a time** — selected at build time by `-Dplatform_backend`
- **Vendored external libraries** when a backend needs them (today: GLFW)

Engine code never sees a backend choice — it imports `platform` and calls the stable API. Backends rotate underneath across sub-repo versions.

This is the second meta-package adapter under zVoxRealms; the first is [`zig-cpp-vulkan-stack-adapter`](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter). Both follow the `zig-cpp-<name>-stack-adapter` naming convention.

## What it's needed for

zVoxRealms ([`docs/external-libs-catalog.md` § 3 Platform-stack](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/external-libs-catalog.md)) needs a windowing + input layer that:

1. **Survives the GLFW → native transition.** v0–v1.0 uses GLFW for rapid iteration. v1.x onward uses pure-Zig X11/Wayland/Win32/Android backends. Same public API across both — engine source changes nowhere
2. **Tree-shakes per export target.** When exporting a game for Linux, Windows/macOS/Android backend code is never compiled in (per-target source selection in `build.zig`). Verifiable with `nm libzvox-runtime.so`
3. **Exposes action-mapped input from day one.** Direct key/button reads are anti-patterns for rebindable games. `bindAction` / `actionPressed` / `actionValue` is the public surface; raw key codes stay inside the backend
4. **Supports Input Mapping Contexts.** Stackable binding layers (gameplay / dialog / inventory / cinematic) so gameplay code never gates on "is dialog open"
5. **Supports synthetic action injection.** Drives the same downstream path as real input — powers integration tests, scripted cutscenes, tutorial overlays
6. **Exposes per-OS native handle getters without depending on Vulkan or on any other adapter.** The adapter provides `getX11Handle` / `getWaylandHandle` / `getWin32Handle` / `getAndroidHandle`, each returning inline-anon structs of raw OS primitives (or `null` if the current backend isn't that OS). The renderer ([`zig-cpp-vulkan-stack-adapter`](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)) has matching `createX11Surface` / `createWaylandSurface` / etc., each taking only raw primitives. **No shared type crosses the adapter boundary** — both adapters are fully standalone. A headless server, config editor, or any non-rendering tool can use this adapter without dragging vulkan-zig along. Engine bridges via a small `src/render/surface.zig` helper that comptime-branches on `builtin.target.os.tag`. Pattern matches GLFW's `glfw3native.h` getters + Vulkan's own `VK_KHR_*_surface` extension pairs

Full spec: [`docs/specs/platform.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/specs/platform.md) in the parent project.

## Which libraries this adapter will use and adapt

These land here progressively as the adapter's roadmap advances. Each is wrapped behind the same stable Zig API.

### v0–v1.0 backend — GLFW

| Library | License | Role | Integration |
| --- | --- | --- | --- |
| [**GLFW**](https://github.com/glfw/glfw) | Zlib | Cross-platform window + input + monitor + gamepad | Vendored as a git submodule under `vendor/glfw/`; compiled by `build.zig` only when `-Dplatform_backend=glfw`. The backend calls `glfwGetX11Window`, `glfwGetWin32Window`, etc. to extract the native handle that `nativeHandle()` exposes |

The GLFW backend is a single file (`src/backend/glfw.zig`) — GLFW itself handles per-OS dispatch internally.

**No Vulkan deps and no cross-adapter deps.** This adapter exposes raw OS primitives only. The renderer (in [`zig-cpp-vulkan-stack-adapter`](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)) has independent per-OS surface creators that take the same raw primitives. Engine wires the two via a small `src/render/surface.zig` helper. No shared types cross the adapter boundary — each adapter is fully standalone.

### v1.x onward — pure-Zig native backends

The native backend ships when the engine moves past v1.0. Each OS gets its own file, selected at build time per target:

| Library / Subsystem | Where | Wrapped how |
| --- | --- | --- |
| [**xcb / Xlib**](https://xcb.freedesktop.org/) (X11) | `src/backend/native/linux_x11.zig` | Pure-Zig `extern fn` calls; no C wrapping needed for X11 |
| [**Wayland protocols**](https://wayland.app/) | `src/backend/native/linux_wayland.zig` | Pure-Zig protocol implementation against `libwayland-client`; XML protocol descriptions compiled to Zig at build time |
| [**Win32 API**](https://learn.microsoft.com/en-us/windows/win32/api/) | `src/backend/native/windows.zig` | Pure-Zig via `std.os.windows` + `extern fn` for user32/gdi32/xinput |
| **AInputQueue / ANativeWindow** (Android NDK) | `src/backend/native/android.zig` | Pure-Zig NDK bindings; activity lifecycle hooks |
| **NSWindow / Cocoa** (macOS) | _deferred_ — `mission.md` defers macOS post-v1.0 | Likely Objective-C runtime via `objc.zig` |

The native backend has no C dependencies — it replaces GLFW entirely. The migration trigger is bumping this sub-repo from v1.x to v2.0 in the consumer's `build.zig.zon`. Engine source changes nowhere across the swap.

### Optional supporting libraries (under evaluation)

| Library | License | Why we might adopt |
| --- | --- | --- |
| **libxkbcommon** | MIT | If pure-Zig X11/Wayland keymap code becomes too painful, libxkbcommon is the universal Linux input keymap layer |
| **libudev** | LGPL | ❌ rejected — LGPL is forbidden per [`licensing.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/licensing.md). Gamepad hotplug events handled via `/dev/input/event*` polling or `epoll` on `/sys/class/input/` |
| **wayland-protocols XML** | MIT | Pre-compiled Zig bindings from the protocol XMLs; build-time generator |

LGPL libraries (libudev, libnice, gettext libintl) are explicitly forbidden per the parent project's licensing policy. The pure-Zig native backend implements equivalent functionality from primitives instead.

---

## Current state — Phase 0 hello-world

The repo currently contains a Zig + C + C++ hello-world stub inherited from the build template, plus:

- `LICENSE` — MIT
- `.clang-format` — Google C++ baseline + zVoxRealms tweaks (matches root project's [`docs/cpp-style.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/cpp-style.md))
- `build.zig.zon` — package manifest

Real platform wrapping has not started yet. Track progress at [zVoxRealms ROADMAP § Phase 1](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/ROADMAP.md).

## Planned layout (target — not yet on disk)

```text
.
├── LICENSE
├── README.md
├── .clang-format
├── build.zig                          # per-target backend selection
├── build.zig.zon
├── src/
│   ├── root.zig                       # public API — re-exports from `backend` module
│   ├── common.zig                     # shared types: Event, KeyCode, WindowOptions, ActionId
│   ├── action_input.zig               # action-mapping + Input Mapping Contexts + synthetic injection
│   ├── native_handle.zig              # per-backend native window handle extraction
│   ├── backend/
│   │   ├── glfw.zig                   # v0 backend — single file
│   │   └── native/                    # v1.x backend — file per OS
│   │       ├── linux.zig              # runtime-dispatches X11 vs Wayland
│   │       ├── linux_x11.zig
│   │       ├── linux_wayland.zig
│   │       ├── windows.zig
│   │       ├── macos.zig              # deferred post-v1.0
│   │       └── android.zig
│   └── tests/                         # integration tests against the public API
└── vendor/
    └── glfw/                          # external lib as git submodule
                                       # compiled only when backend=glfw
```

`vendor/glfw/` is a **vendored dependency** of the adapter, not a sub-library. Structurally identical to how the Vulkan-stack adapter vendors its C++ libs.

## Build (template / hello-world)

```sh
zig build run
```

Requires **Zig 0.16 or newer**. The build script and `main.zig` use post-0.16 APIs (the `Io` interface, the `Module`-based `addExecutable`, the unmanaged `ArrayList`, and `pub fn main(init: std.process.Init)`).

When backend selection lands, the build will add a `-Dplatform_backend=glfw|native` option.

## Consuming this adapter

When real wrapping lands, consumers will use:

```zig
// In your build.zig.zon
.dependencies = .{
    .platform_stack_adapter = .{
        .url = "git+https://github.com/SETA1609/zig-cpp-platform-stack-adapter.git#<tag>",
        .hash = "...",
    },
},
```

```zig
// In your Zig code
const platform = @import("platform");

const window = try platform.Window.create(.{
    .title = "my game",
    .size = .{ .w = 1280, .h = 720 },
    .vulkan_compatible = true,
});

if (platform.actionPressed(.jump)) player.jump();
```

## Cross-reference

- Parent project: [zVoxRealms](https://github.com/SETA1609/zigVoxelWorlds)
- Catalog entry: [`docs/external-libs-catalog.md` § 3 Platform-stack](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/external-libs-catalog.md)
- API contract: [`docs/specs/platform.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/specs/platform.md)
- Sibling adapter: [zig-cpp-vulkan-stack-adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter)
- Licensing policy: [`docs/licensing.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/licensing.md)
- C++ style: [`docs/cpp-style.md`](https://github.com/SETA1609/zigVoxelWorlds/blob/main/docs/cpp-style.md)

## Adapter pattern note — the two C ABIs

zVoxRealms has two distinct `extern "C"` surfaces and this adapter touches one of them:

1. **Internal adapter bridge** (this repo) — when a backend has C++ pieces (none today; possibly some macOS Objective-C++ later), they're wrapped in `extern "C"` and re-exported as idiomatic Zig types
2. **Public mod/script ABI** — a separate concern, lives in the parent project's `docs/specs/c-abi.md`. Not consumed by this adapter

Adapter authors care about (1). Mod authors care about (2). The two aren't the same surface.
