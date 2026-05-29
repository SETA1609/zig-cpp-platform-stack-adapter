//! Smoke demo for `zig build run`.
//!
//! Prints library info using only the **pure-data** surface (version, option
//! defaults) — it does NOT call the stubbed backend, so it runs to a clean
//! exit today. Once the SDL3 backend lands this is the natural place to grow a
//! real open-a-window demo. Not shipped to consumers (outside `build.zig.zon`
//! `.paths`).

const std = @import("std");
const platform = @import("platform");

pub fn main() void {
    const defaults: platform.WindowOptions = .{ .title = "demo" };
    std.debug.print(
        \\platform-stack-adapter {s}
        \\  default window : {d}x{d}, renderer={s}, resizable={}
        \\  backend        : SDL3 (surface is @panic stubs until v0.6.0)
        \\
    , .{
        platform.version,
        defaults.size.w,
        defaults.size.h,
        @tagName(defaults.renderer),
        defaults.resizable,
    });
}
