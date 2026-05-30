# Security Policy — zig-cpp-platform-stack-adapter

## Supported versions

Pre-1.0, single-maintainer library. Security fixes land on the **latest tagged release + `main`** only; there are no long-term-support branches.

| Version | Supported |
| --- | --- |
| latest tag / `main` | ✅ |
| older tags | ❌ (upgrade to latest) |

## Reporting a vulnerability

**Please do not open a public issue for a security problem.** Report privately via a **[GitHub Security Advisory on this repo](https://github.com/SETA1609/zig-cpp-platform-stack-adapter/security/advisories/new)** (or, if you prefer, on the [parent project](https://github.com/SETA1609/zigVoxelWorlds/security/advisories/new) that maintains it).

Include: affected version / commit, platform + backend (SDL3 + OS / display server), reproduction steps, and impact. Expect a best-effort acknowledgement — this is a small project.

## Scope / threat model

This library is a **windowing + input + OS-services** layer. It is not network-facing. Realistic surface:

- Handling of OS / event data, **clipboard and IME text** input, and **file-drop** paths.
- **Filesystem-path construction** (`appDataDir` / `appCacheDir`) — path traversal or injection via an attacker-controlled app name.
- Exposure of **native window handles** (raw pointers) across the API.

## Upstream dependencies

This library builds **SDL3** (via [`castholm/SDL`](https://github.com/castholm/SDL)). Vulnerabilities in SDL itself should be reported to **[SDL upstream](https://github.com/libsdl-org/SDL/security)**; once fixed there, this library bumps its pinned dependency. Packaging issues in the Zig build belong to the castholm/SDL repo.

## Out of scope

Bugs that require an already-compromised process, or that live entirely in a consumer's own renderer / app code, are not vulnerabilities in this library.
