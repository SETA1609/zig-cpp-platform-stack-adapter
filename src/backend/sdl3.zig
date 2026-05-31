//! SDL3 backend for the platform adapter.
//!
//! This is the **only** file that touches SDL — `root.zig` delegates here, and
//! no `SDL_*` type ever crosses back out to the public API (design Rule 1). The
//! C surface is reached through `@cImport`; the SDL3 headers come from the
//! `castholm/SDL` artifact that `build.zig` links into the module.
//!
//! Implemented incrementally along the ladder in `CONTRIBUTING.md`. Filled so
//! far: lifecycle (step 1), time (step 2).

const std = @import("std");

/// SDL3's C API. Behind this boundary only — never re-exported.
pub const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

// =============================================================================
// Lifecycle  (ladder step 1)
// =============================================================================

/// Bring up the requested SDL subsystems. Maps the public `InitOptions` to
/// SDL init flags; `SDL_Init` returns `false` on failure.
pub fn init(video: bool, gamepad: bool, audio: bool) !void {
    var flags: c.SDL_InitFlags = 0;
    if (video) flags |= c.SDL_INIT_VIDEO;
    if (gamepad) flags |= c.SDL_INIT_GAMEPAD;
    if (audio) flags |= c.SDL_INIT_AUDIO;
    if (!c.SDL_Init(flags)) return error.BackendInitFailed;
}

/// Tear down all SDL subsystems. Pairs with `init`; safe to re-`init` after.
pub fn deinit() void {
    c.SDL_Quit();
}

// =============================================================================
// Time  (ladder step 2)
// =============================================================================

/// Monotonic nanoseconds since SDL init.
pub fn now() u64 {
    return c.SDL_GetTicksNS();
}

/// Ticks per second of the high-resolution performance counter.
pub fn perfFreq() u64 {
    return c.SDL_GetPerformanceFrequency();
}

/// Raw high-resolution performance counter value.
pub fn perfCounter() u64 {
    return c.SDL_GetPerformanceCounter();
}

/// Block the calling thread for at least `ns` nanoseconds.
pub fn sleep(ns: u64) void {
    c.SDL_DelayNS(ns);
}
