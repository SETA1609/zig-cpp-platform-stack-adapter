# Candidate issues — platform-stack adapter

Each section is a standalone, real-world task: explore the codebase, implement
the behavior, and make it pass programmatically. All public types are in
`src/common.zig`; the public API is in `src/root.zig`; the only file that may
touch SDL is `src/backend/sdl3.zig` (design Rule 1 — **no `SDL_*` type may cross
the public API**). The gated red→green suite lives in `src/tests/tdd/`.

---

## Issue 1 — Input contexts don't work: gameplay actions fire while a menu is open

`pushContext` / `popContext` / `replaceTopContext` / `activeContext` /
`isContextActive` (`src/root.zig`, ~line 407) are all `@panic("not implemented")`.
A game can't tell whether it's in `gameplay` vs `ui_menu`, so it can't gate input
by mode. Implement the context **stack** the public API already declares.

The library names no contexts of its own — every function is generic over the
caller's own enum (see the `ActionId`/`InputContextId` doc comments in
`common.zig` and the `toId` helper in `root.zig`).

**Requirements** (exercised by `src/tests/tdd/08_context_test.zig` — flip its
`done` flags as you implement):

1. `pushContext(x)` then `activeContext(Ctx)` returns `x` (as a value of the
   caller's enum type `Ctx`).
2. The stack is **LIFO**: push `a`, push `b` → `activeContext` is `b`; after
   `popContext` it is `a`.
3. `popContext(Ctx)` removes and returns the top; **calling it on an empty stack
   returns `null`** (not a crash, not a garbage value). `activeContext` on an
   empty stack also returns `null`.
4. `replaceTopContext(x)` swaps the top in place without changing the stack
   depth. On an **empty** stack it is equivalent to `pushContext(x)` (depth
   becomes 1).
5. `isContextActive(x)` is `true` iff `x` equals the current top context.
6. Contexts are process state: a `deinit()` followed by a fresh `init()` must
   start with an **empty** stack (`activeContext` → `null`).

**Notes.** Store contexts as the 16-bit `InputContextId` space (`toId`), and
reconstruct the caller's enum with `@enumFromInt` on the way out. The backend
already resets `binds`/`injects`/`states` in `deinit` — context state belongs
there too.

---

## Issue 2 — App data/cache directories are unimplemented

`applicationDataDirectory` and `applicationCacheDirectory`
(`allocator, application_name`) and `openWithSystemDefault(path)` in
`src/root.zig` (~line 474) are `@panic` stubs. Engines need a per-user writable
location for saves/config and a separate disposable cache dir. Implement them
over SDL3 (`SDL_GetPrefPath`, `SDL_OpenURL`).

**Requirements** (`src/tests/tdd/10_paths_test.zig`):

1. `applicationDataDirectory(alloc, "myapp")` returns a **non-empty, absolute**
   path that **ends with the OS path separator**, and the directory exists
   (created if needed).
2. The returned slice is **owned by the caller's `allocator`** and frees cleanly
   with it (no leak; the test runs under the testing allocator).
3. `applicationCacheDirectory` returns a path **distinct** from the data dir,
   also caller-owned and existing.
4. `openWithSystemDefault` returns without error for a well-formed `file://`
   path / URL and surfaces a Zig error (not a panic) on failure.

**Notes.** `SDL_GetPrefPath` returns a string **SDL owns and that must be
released with `SDL_free`** — copy it into the caller's `allocator` and free the
SDL buffer; never hand the SDL pointer back as if it were caller-owned. Watch
the trailing separator: SDL's pref path already ends with one — don't double it.

---

## Issue 3 — No clipboard access

Add global clipboard support (SDL clipboard is process-global, so these are free
functions next to the cursor functions in `src/root.zig`, not `Window` methods):

```zig
pub fn setClipboardText(text: []const u8) void;
pub fn clipboardText(allocator: std.mem.Allocator) ![]u8;
```

**Requirements:**

1. `setClipboardText("hello")` then `clipboardText(alloc)` returns exactly
   `"hello"`.
2. The returned slice is owned by the caller's `allocator`.
3. When the clipboard is empty, `clipboardText` returns an **empty slice**
   (`len == 0`), never a panic.
4. UTF-8 round-trips unchanged (e.g. `"héllo →"`).
5. The decoupling invariant holds: a `renderer = .none` build still links **zero
   `vk*`/`VK_`** symbols (`docs/manual-testing.md` §8).

**Notes.** `SDL_GetClipboardText` returns an **SDL-allocated** string that must
be freed with `SDL_free` after you copy it into the caller's allocator; the SDL
backend needs the video subsystem initialised (it is, after `init`).
