# Manual / e2e testing — zig-cpp-platform-stack-adapter

> The companion to the automated [`src/tests/tdd/`](../src/tests/tdd) suite.
> Everything that **can** be proven in-process lives there (run it with
> `zig build test-tdd`). This file covers the functions whose only proof is a
> **human looking at the result**, **real hardware input**, or a **live
> GPU/GL/Vulkan surface** — things no headless assertion can verify.
>
> Each entry lists: the API, what to do, and the **pass criterion**. Run them on
> a real desktop session. Where behavior diverges by OS / display server, the
> divergence is the test — repeat the relevant rows on each target
> (`x86_64-linux-gnu` under **both** X11 and Wayland, and `x86_64-windows-gnu`).

## Coverage status — as of `49d2b7c`

What is **proven today**. Every public function is still a `@panic("not
implemented")` stub at this commit, so the entire behavioral surface is
unproven — only the pure-data contract layer is green. Re-tick each box as its
backend lands and the matching TDD test / e2e procedure passes; bump the commit
hash in this heading when you do.

**Automated — `zig build test`** (contract/data, must stay green):

- [x] Enum numeric values, struct defaults, type layout (`src/tests/api_test.zig`)

**Automated — `zig build test-tdd`** (red→green; all RED now):

- [ ] Lifecycle: `init` / `deinit`
- [ ] Window: `create` / `destroy` / `size` / `shouldClose` / `scaleFactor` / `setSize`
- [ ] Events: `pollAllEvents` / `nextEvent` / `events` (idle-frame invariants)
- [ ] Action state machine: `injectAction` → `actionPressed` / `actionJustPressed` / `actionJustReleased` / `actionValue`
- [ ] Action bindings accept every shape: `bindAction` / `unbindAction`
- [ ] Input contexts: `pushContext` / `popContext` / `replaceTopContext` / `activeContext` / `isContextActive`
- [ ] Time: `now` / `perfFreq` / `perfCounter` / `sleep`
- [ ] Filesystem: `appDataDir` / `appCacheDir`
- [ ] Vulkan hand-off: `requiredVulkanInstanceExtensions`; native-handle presence invariants

**Manual / e2e** (this document; all UNPROVEN now):

- [ ] §1 Window appearance & geometry (visual): title, position, HiDPI scale, fullscreen/borderless
- [ ] §2 Real OS event delivery: key / mouse / scroll / resize / focus / close / text-input / file-drop / gamepad
- [ ] §3 Real key → action mapping
- [ ] §4 OpenGL path: context / make-current / proc-address / swap / swap-interval / destroy
- [ ] §5 Filesystem persistence + `openWithSystemDefault`
- [ ] §6 Native Vulkan handle **validity** (cross-lib surface creation)
- [ ] §7 Capabilities per-session values (X11 vs Wayland vs Windows)
- [ ] §8 `nm` decoupling check (zero `vk*`/`VK_` symbols)

## How to run these

There is no automated harness for these — they are driven by the validation
apps (see [`validation-apps.md`](validation-apps.md)) and by short throwaway
snippets. The minimal scaffold every procedure assumes:

```zig
const platform = @import("platform");
try platform.init(.{});
defer platform.deinit();
const win = try platform.Window.create(.{ .title = "manual", .renderer = .none });
defer win.destroy();
// ... drive a frame loop: while (!win.shouldClose()) { platform.pollAllEvents(); ... }
```

Mark a row `[x]` only when it passes on every target it applies to.

---

## 1. Window appearance & geometry (visual / WM-dependent)

`create`/`destroy`/`size`/`shouldClose` are asserted in the TDD suite. What that
suite **cannot** see is whether a window actually appears, is titled, moves, or
resizes the way a user perceives — those are below.

| API | Procedure | Pass criterion |
| --- | --- | --- |
| `Window.create` | Run the scaffold with `.renderer = .none`. | A window of the requested size actually **appears on screen**, centered (no `position` given). |
| `Window.destroy` | Let the scaffold exit (defer runs). | The window **disappears**; no zombie window, no leaked process. |
| `Window.setTitle` | `win.setTitle("renamed ✓ — UTF-8 ✓");` after a frame. | The **title bar text changes** to exactly that string (UTF-8 glyphs intact). *(No getter exists — eyeball it.)* |
| `Window.setPosition` | `win.setPosition(.{ .x = 100, .y = 100 });` then a few frames. | **X11/Windows:** window moves to ~(100,100). **Wayland:** request is ignored by design — confirm it does **not** crash and `capabilities().can_set_window_position == false`. |
| `Window.position` | After a move (or user drag) on X11/Windows, print `win.position()`. | Returns coordinates matching the window's actual on-screen position. **Wayland:** value is meaningless by design — confirm `capabilities().can_query_window_position == false` and the call doesn't crash. |
| `Window.setSize` (tiling WM) | On a tiling WM (sway/i3), `win.setSize(...)`. | Request may be **clamped/ignored** by the WM — confirm no crash. *(On a floating WM the round-trip is asserted in the TDD suite.)* |
| `Window.scaleFactor` (HiDPI) | Run on a HiDPI monitor (or a 2× scaled display); print `scaleFactor()`. Drag the window between a 1× and a 2× monitor. | Reports the monitor's real scale (e.g. `2.0`); updates when the window changes monitors if `capabilities().high_dpi_scale_per_monitor`. |
| `Window.create` `fullscreen`/`borderless` | Create with `.fullscreen = true`, then separately `.borderless = true`. | Fullscreen covers the display; borderless has **no title bar/border**. |

## 2. Real OS event delivery (needs human input / hardware)

`pollAllEvents`/`nextEvent`/`events` are smoke-tested headlessly for the *empty*
frame. Confirming each **event type is actually produced** by real input is
manual. For each, log events in the frame loop and perform the action.

```zig
platform.pollAllEvents();
while (platform.nextEvent()) |ev| std.debug.print("{any}\n", .{ev});
```

| Event | Action to perform | Pass criterion |
| --- | --- | --- |
| `Event.close` | Click the WM **×** button (or Alt-F4). | A `.close` event arrives; `win.shouldClose()` flips to `true`. Window stays alive until `destroy`. |
| `Event.key` | Press & release several keys, incl. modifiers, and **hold** one. | `.key` events with correct `code` (physical position — WASD is WASD on AZERTY), `pressed`, `repeat` (true only on OS auto-repeat), and `mods`. |
| `Event.mouse_button` | Left/right/middle click; double-click; thumb buttons. | `.mouse_button` with right `button`, `pressed`, `clicks` (2 on double), and `x/y` at the cursor. |
| `Event.mouse_motion` | Move the pointer across the window. | `.mouse_motion` with absolute `x/y` and sensible `dx/dy` deltas. |
| `Event.mouse_scroll` | Scroll wheel up/down and (if available) horizontal. | `.mouse_scroll`; positive `y` = scroll **up**/away. |
| `Event.resize` | Drag a window edge to resize. | `.resize` with the new **drawable** size in pixels (DPI-scaled); matches `win.size()` afterward. |
| `Event.focus` | Alt-Tab away and back. | `.focus` with `focused=false` on blur, `true` on regain. |
| `Event.text_input` *(v0.8.0)* | Type text incl. an IME composition (e.g. accented chars). | `.text_input` carries the **composed UTF-8 characters**, distinct from raw `.key` events. |
| `Event.file_drop` *(v0.8.0)* | Drag a file from the file manager onto the window. | `.file_drop` per file with the absolute UTF-8 `path` and drop `x/y`. |
| `Event.gamepad` *(v0.8.0)* | Plug in a controller; press buttons; move sticks/triggers; unplug. | `.gamepad` events: `connected`/`disconnected`, `button` transitions, `axis` values in `[-1,1]` (triggers `[0,1]`). |

## 3. Action bindings — real key → action mapping

The TDD suite proves the **action state machine** via `injectAction`, and proves
`bindAction`/`unbindAction` *accept* every binding shape. It cannot prove that a
bound **physical key** drives the action — that needs real input.

| API | Procedure | Pass criterion |
| --- | --- | --- |
| `bindAction` (key) | `bindAction(.menu_pause, .{ .key = .escape })`; press **Esc**. | `actionJustPressed(.menu_pause)` is `true` exactly **once per press** (edge, not on hold/repeat). |
| `bindAction` (any-of / composite) | Bind `.move_forward` to `.w` **and** `.up`; press either. | `actionPressed(.move_forward)` is true for **either** key. |
| `bindAction` (mouse / gamepad) | Bind an action to a mouse button / gamepad button; trigger it. | The action reads as pressed from that source. |
| `unbindAction` | Bind `.menu_pause`→Esc, confirm Esc fires it, then `unbindAction` the same binding; press Esc again. | After unbinding, Esc **no longer** fires `.menu_pause`. |
| `actionValue` (gamepad axis, v0.8.0) | Bind a `.gamepad_axis` with deadzone/scale/invert; move the stick. | Value reflects the shaping: below `threshold` reads 0; `invert` flips sign; `scale` multiplies; smoothing eases. |

## 4. OpenGL path (needs a GL driver + visual confirmation)

The whole GL path produces no in-process-verifiable value — the proof is pixels
on screen and frame pacing. Drive it with the **GL clear-color** validation app.

| API | Procedure | Pass criterion |
| --- | --- | --- |
| `glCreateContext` | Create a window with `.renderer = .opengl`, then `glCreateContext(win)`. | Returns a non-null context; no GL error. |
| `glMakeCurrent` | `glMakeCurrent(win, ctx)`. | Subsequent GL calls succeed on the calling thread. |
| `glGetProcAddress` | Look up `"glClear"` (valid) and `"glNotAReal_Fn"` (bogus). | Valid name → non-null pointer; bogus name → `null`. |
| `glSwapWindow` | Each frame: `glClearColor(0,1,0,1); glClear(...); glSwapWindow(win);` | A **solid green** window; no tearing artifacts beyond vsync setting. |
| `glSetSwapInterval` | Set `1` (vsync) then `0` (off); measure frame time over ~2s. | `1` ≈ caps to refresh rate (e.g. ~16.6 ms @ 60 Hz); `0` runs uncapped (much faster). `-1` adaptive where supported. |
| `glDestroyContext` | Call at shutdown. | No crash; GL resources released; window can be destroyed cleanly. |

## 5. Filesystem & system integration

| API | Procedure | Pass criterion |
| --- | --- | --- |
| `appDataDir` / `appCacheDir` | (Path shape is asserted in the TDD suite.) Write a file into the returned dir, restart, read it back. | Data dir **persists** across runs; both dirs exist and are writable; they follow OS conventions (`~/.local/share`, `%APPDATA%`, `~/Library/...`). |
| `openWithSystemDefault` | `openWithSystemDefault("https://example.com")` and a local file path. | The OS default handler **launches** (browser opens the URL; file opens in its app). Side-effecting — no assertion possible. |

## 6. Native Vulkan handles — *validity* (cross-lib e2e)

The TDD suite proves **which** OS getter is live and that the host getter is
non-null. It cannot prove the returned pointers are **usable** — that is only
proven by handing them to a Vulkan surface creator and presenting. This is the
cross-library integration test against the companion **vulkan-stack adapter**
(see its `docs/manual-testing.md` and the examples-repo **Vulkan clear-color**
rung).

| API | Procedure | Pass criterion |
| --- | --- | --- |
| `getX11Handle` / `getWaylandHandle` / `getWin32Handle` | Pass the handle from a `.renderer = .vulkan` window into the matching `vulkan_stack.create*Surface(instance, ...)`. | A valid, non-null `VkSurfaceKHR`; a swapchain built on it presents frames. |
| `requiredVulkanInstanceExtensions` | (Presence/`VK_KHR_surface` is asserted in the TDD suite.) Pass the list to `VkInstanceCreateInfo`. | `vkCreateInstance` **succeeds** with exactly these extensions and the resulting instance can create the platform surface. |

## 7. Capabilities — per-session values

The TDD suite proves `capabilities()` is callable and self-consistent. The
actual booleans are environment truths to confirm by hand:

| Field | X11 | Wayland | Windows |
| --- | --- | --- | --- |
| `can_set_window_position` | `true` | **`false`** | `true` |
| `can_query_window_position` | `true` | **`false`** | `true` |
| `can_capture_global_input` | usually `true` | restricted | `true` |
| `high_dpi_scale_per_monitor` | session-dependent | `true` | `true` |

Run on each session and confirm the reported value matches reality (e.g. on
Wayland, `setPosition` is a no-op **and** the flag is `false`).

## 8. Required decoupling check (`nm`)

A hard gate from [`validation-apps.md`](validation-apps.md), repeated here as it
is a manual command, not a unit test. After building a `renderer = .none`
binary (the **Event logger**):

```sh
nm <binary> | grep -i 'vk[A-Z]\|VK_'   # must print NOTHING
```

**Pass:** empty output — this library drags **no Vulkan** into a window that
didn't ask for one. A non-empty result is a boundary leak to fix immediately.
