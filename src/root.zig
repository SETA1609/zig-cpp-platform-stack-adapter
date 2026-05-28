//! Public Zig API for the platform-stack adapter.
//!
//! Stub. The v0.6.0 surface (Window create/destroy, event pump, renderer
//! selection, per-OS native handle getters, requiredVulkanInstanceExtensions,
//! GL context, minimal key action binding) lands across the Sprint 1 plan
//! in docs/sprint.md. The SDL3 backend will live under src/backend/sdl3.zig
//! and is linked in via the `platform` static-library artifact produced by
//! build.zig.

pub const version = "0.6.0-dev";
