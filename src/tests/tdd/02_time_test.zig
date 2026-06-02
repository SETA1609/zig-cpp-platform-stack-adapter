//! Ladder step 2 — **time** (`now` / `performanceFrequency` / `performanceCounter` / `sleep`).
//! *(v0.6.0)* Needs step 1 (`init`). Flip each function's `done` flag as you
//! implement it; the cross tests need both their flags. See `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .now = true,
    .performanceFrequency = true,
    .performanceCounter = true,
    .sleep = true,
};

// WHEN reading now twice back-to-back · GIVEN the platform is started · THEN the second reading is greater than or equal to the first.
test "now: is monotonic non-decreasing" {
    try gate(done.now);
    try h.startup();
    defer platform.deinit();
    const t0 = platform.now();
    const t1 = platform.now();
    try std.testing.expect(t1 >= t0);
}

// WHEN reading now twice back-to-back · GIVEN the platform is started · THEN the elapsed difference is under one second.
test "now: two back-to-back reads differ by less than a second" {
    try gate(done.now);
    try h.startup();
    defer platform.deinit();
    const t0 = platform.now();
    const t1 = platform.now();
    try std.testing.expect(t1 - t0 < std.time.ns_per_s);
}

// WHEN reading now before and after a 2ms sleep · GIVEN the platform is started · THEN the later reading is strictly greater than the earlier one.
test "now: advances across a short sleep" {
    try gate(done.now and done.sleep);
    try h.startup();
    defer platform.deinit();
    const t0 = platform.now();
    platform.sleep(2 * std.time.ns_per_ms);
    try std.testing.expect(platform.now() > t0);
}

// WHEN reading performanceFrequency · GIVEN the platform is started · THEN the frequency is positive.
test "performanceFrequency: is positive" {
    try gate(done.performanceFrequency);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.performanceFrequency() > 0);
}

// WHEN reading performanceFrequency twice · GIVEN the platform is started · THEN both readings are equal.
test "performanceFrequency: is stable across calls" {
    try gate(done.performanceFrequency);
    try h.startup();
    defer platform.deinit();
    try std.testing.expectEqual(platform.performanceFrequency(), platform.performanceFrequency());
}

// WHEN reading performanceFrequency · GIVEN the platform is started · THEN the frequency is at least 1000 Hz (high resolution).
test "performanceFrequency: is a high-resolution frequency (>= 1000 Hz)" {
    try gate(done.performanceFrequency);
    try h.startup();
    defer platform.deinit();
    try std.testing.expect(platform.performanceFrequency() >= 1000);
}

// WHEN reading performanceCounter twice back-to-back · GIVEN the platform is started · THEN the second reading is greater than or equal to the first.
test "performanceCounter: is non-decreasing" {
    try gate(done.performanceCounter);
    try h.startup();
    defer platform.deinit();
    const c0 = platform.performanceCounter();
    const c1 = platform.performanceCounter();
    try std.testing.expect(c1 >= c0);
}

// WHEN reading performanceCounter before and after a 2ms sleep · GIVEN the platform is started · THEN the later reading is strictly greater than the earlier one.
test "performanceCounter: advances across a sleep" {
    try gate(done.performanceCounter and done.sleep);
    try h.startup();
    defer platform.deinit();
    const c0 = platform.performanceCounter();
    platform.sleep(2 * std.time.ns_per_ms);
    try std.testing.expect(platform.performanceCounter() > c0);
}

// WHEN computing (performanceCounter delta)/performanceFrequency across a 5ms sleep · GIVEN the platform is started · THEN the elapsed seconds is greater than 0 and less than 1.
test "performanceCounter: divided by performanceFrequency yields a sane elapsed second-count" {
    try gate(done.performanceCounter and done.performanceFrequency and done.sleep);
    try h.startup();
    defer platform.deinit();
    const freq = platform.performanceFrequency();
    const c0 = platform.performanceCounter();
    platform.sleep(5 * std.time.ns_per_ms);
    const c1 = platform.performanceCounter();
    const elapsed_s = @as(f64, @floatFromInt(c1 - c0)) / @as(f64, @floatFromInt(freq));
    try std.testing.expect(elapsed_s > 0.0 and elapsed_s < 1.0);
}

// WHEN calling sleep(0) · GIVEN the platform is started · THEN it returns without error.
test "sleep: sleeping zero returns without error" {
    try gate(done.sleep);
    try h.startup();
    defer platform.deinit();
    platform.sleep(0);
}

// WHEN sleeping 5ms and measuring elapsed now · GIVEN the platform is started · THEN at least ~1ms elapsed (generous slack for timer granularity).
test "sleep: blocks for at least roughly the requested duration" {
    try gate(done.sleep and done.now);
    try h.startup();
    defer platform.deinit();
    const t0 = platform.now();
    platform.sleep(5 * std.time.ns_per_ms);
    // Generous slack below the request for timer granularity.
    try std.testing.expect(platform.now() - t0 >= 1 * std.time.ns_per_ms);
}

// WHEN measuring a 2ms sleep then a 10ms sleep · GIVEN the platform is started · THEN the longer sleep's measured duration exceeds the shorter one's.
test "sleep: a longer sleep blocks longer than a shorter one" {
    try gate(done.sleep and done.now);
    try h.startup();
    defer platform.deinit();
    const a0 = platform.now();
    platform.sleep(2 * std.time.ns_per_ms);
    const short = platform.now() - a0;
    const b0 = platform.now();
    platform.sleep(10 * std.time.ns_per_ms);
    const long = platform.now() - b0;
    try std.testing.expect(long > short);
}
