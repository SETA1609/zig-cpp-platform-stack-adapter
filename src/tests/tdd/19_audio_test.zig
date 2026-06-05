//! Ladder step 19 — **audio** (`openAudioStream` + `AudioStream.queue`/`queued`/
//! `clear`/`destroy`, `loadWav`/`freeWav`). *(v0.10.0)* Needs step 1 (`init`).
//! The `AudioSpec` defaults are provable in-process; opening a real device +
//! hearing playback is the manual e2e in `docs/manual-testing.md`. See
//! `CONTRIBUTING.md`.

const std = @import("std");
const platform = @import("platform");
const h = @import("harness.zig");
const gate = h.gate;

const done = .{
    .openAudioStream = false,
    .queue = false,
    .queued = false,
    .clear = false,
};

// WHEN reading a default AudioSpec · GIVEN the audio types · THEN it is 48 kHz, stereo, f32.
test "audio: AudioSpec defaults to 48kHz stereo f32" {
    try gate(done.openAudioStream);
    const spec: platform.AudioSpec = .{};
    try std.testing.expectEqual(@as(u32, 48_000), spec.frequency);
    try std.testing.expectEqual(@as(u8, 2), spec.channels);
    try std.testing.expectEqual(platform.AudioFormat.float32, spec.format);
}

// WHEN opening a stream, queueing PCM, then clearing · GIVEN a started platform · THEN the calls succeed and queued() is readable.
test "audio: open, queue PCM, then drain" {
    try gate(done.openAudioStream and done.queue and done.queued and done.clear);
    try h.startup();
    defer platform.deinit();
    const stream = try platform.openAudioStream(.{});
    defer stream.destroy();
    const silence = [_]u8{0} ** 64;
    try stream.queue(&silence);
    _ = stream.queued();
    stream.clear();
}
