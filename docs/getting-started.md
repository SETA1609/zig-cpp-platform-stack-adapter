# Getting started — platform adapter

A from-scratch walkthrough: add the dependency, wire the build, and write a
minimal window + input loop. For the API reference see [`api.md`](api.md); for
how SDL3 works underneath see [`sdl3-cheat-sheet.md`](sdl3-cheat-sheet.md).

**Requires Zig 0.16+.**

## 1. Add the dependency

```sh
zig fetch --save git+https://github.com/SETA1609/zig-cpp-platform-stack-adapter.git#<tag>
```

That writes a pinned entry into your `build.zig.zon`:

```zig
.dependencies = .{
    .platform = .{ .url = "git+https://github.com/SETA1609/zig-cpp-platform-stack-adapter.git#<tag>", .hash = "..." },
},
```

## 2. Wire the build

The lib exposes a **module** (`platform`, the Zig API) and a **static-library
artifact** (`platform`, the compiled code incl. SDL3). Import the module *and*
link the artifact:

```zig
// build.zig
const platform_dep = b.dependency("platform", .{ .target = target, .optimize = optimize });

const exe = b.addExecutable(.{ .name = "app", .root_module = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target, .optimize = optimize,
}) });
exe.root_module.addImport("platform", platform_dep.module("platform")); // the API
exe.root_module.linkLibrary(platform_dep.artifact("platform"));         // SDL3, compiled once
b.installArtifact(exe);
```

## 3. A minimal app

```zig
const std = @import("std");
const platform = @import("platform");

// Your game owns the action vocabulary — the library names none.
const Action = enum(u16) { quit };

pub fn main() !void {
    try platform.init(.{});
    defer platform.deinit();

    const win = try platform.Window.create(.{ .title = "hello", .renderer = .none });
    defer win.destroy();

    platform.bindAction(Action.quit, .{ .key = .escape });

    while (!win.shouldClose()) {
        platform.pollAllEvents();
        while (platform.nextEvent()) |ev| switch (ev) {
            .close => return,
            .key => |k| std.debug.print("key {s} pressed={}\n", .{ @tagName(k.code), k.pressed }),
            else => {},
        };
        if (platform.actionJustPressed(Action.quit)) break;
        platform.sleep(8 * std.time.ns_per_ms); // ~120 fps placeholder
    }
}
```

`zig build run` (or your run step) opens a window, prints key events, and quits
on Esc or the window's close button.

## 4. What works today vs. what traps

Implemented (v0.6.0): **window** (create/destroy/size/setSize/scaleFactor/
setTitle/setPosition/position/shouldClose), **events** (pollAllEvents/nextEvent/
events), **time** (now/performanceFrequency/performanceCounter/sleep), **action-mapped input**
(bindAction/unbindAction/actionPressed/actionJustPressed/actionJustReleased/
actionValue/injectAction — all over *your* enum), and the **Vulkan hand-off**
(getX11Handle/getWaylandHandle/getWin32Handle/getAndroidHandle +
requiredVulkanInstanceExtensions).

Implemented (v0.7.0): **runtime window state** (setFullscreen/setResizable/
setBordered + the is* getters, setMinSize/setMaxSize + getters, minimize/
maximize/restore/raise) and **mouse capture & cursor** (setRelativeMouseMode/
relativeMouseMode, warpMouse, setMouseGrab/mouseGrabbed, global showCursor/
hideCursor/cursorVisible).

Still `@panic("not implemented")` — **don't call these yet**: the OpenGL path
(`glCreateContext`/…), input **contexts** (`pushContext`/…), `capabilities()`,
and filesystem **paths** (`applicationDataDirectory`/…). See [`ROADMAP.md`](ROADMAP.md).

> Needs a display server (X11/Wayland). For headless CI, run with the SDL dummy
> driver: `SDL_VIDEODRIVER=dummy`.

## 5. Going to Vulkan

For a Vulkan renderer, create the window with `.renderer = .vulkan`, then feed
the native handle + `requiredVulkanInstanceExtensions()` into a Vulkan surface
creator — e.g. the companion
[vulkan adapter](https://github.com/SETA1609/zig-cpp-vulkan-stack-adapter). No
Vulkan type crosses this library's API. See its getting-started for the other half.

## Next

- [`api.md`](api.md) — full signatures + semantics · [`enum-values.md`](enum-values.md) — stable enum maps
- [`sdl3-cheat-sheet.md`](sdl3-cheat-sheet.md) — how the SDL3 backend works
- [`validation-apps.md`](validation-apps.md) — example apps · [`CONTRIBUTING.md`](../CONTRIBUTING.md) — implementing more of the API
