# Changelog

Last updated: 2026-10-28T22:52Z

Changes per issue, newest first. Each PR adds its entry and updates the timestamp above. Issue IDs prefixed `S0-` are from [project-new-world](https://github.com/SETA1609/project-new-world/tree/main/docs/stories), which uses this adapter as its `platform` module. History before this file: `git log`.

## Unreleased

### Docs after the 0.17.0 port

- `README.md`: a Development section for the CI gate, the container CLI, and this changelog; `tools/devops/README.md` in the Documentation list.
- This changelog: entries carry their PR numbers.

## 2026-10-28

### S0-02 Container devops CLI for contributors (#6)

- Add `.zig-version` (`0.17.0`), checked against `ARG ZIG_VERSION` in the `Dockerfile`.
- Add `tools/devops/`, a host-side Python CLI (uv; standard library only at runtime) copied from project-new-world. It runs the toolchain container with every output line timestamped and logged to `cache/logs/`.
- One shim: `./scripts/container.sh <subcommand>` with `image`, `build`, `test`, `zig`, `ci` (runs `scripts/ci.sh`), `tdd` (`zig build test-tdd` under Xvfb with software GL), `shell`, `prune`, and `clean`.
- A leading `--keep-cache` keeps the Zig global cache in the volume `platform-stack-adapter-zig-cache` until `clean`.
- Containers run with `--init`. Without it `xvfb-run` is PID 1 and never sees Xvfb's ready signal, so `tdd` hangs.
- The `Dockerfile` installs the Mesa GL and Vulkan runtime (`libgl1-mesa-dri`, `libglx-mesa0`, `libvulkan1`, `mesa-vulkan-drivers`), as `scripts/install_display_deps.py` does in CI. Without them 4 Vulkan hand-off tests fail.
- `scripts/ci.sh` and `scripts/tdd.sh` are unchanged and still run without a container.
- Checked: `container.sh ci` passes; `container.sh tdd` passes 98 and skips 34 of 132.

### S0-02 Port to Zig 0.17.0 (#5)

- castholm/SDL `v0.5.0+3.4.8` → `v0.6.0+3.4.18`, which targets 0.17.0.
- `@cImport` is removed in 0.17: the SDL includes are in `src/backend/sdl3_c.h`, translated by `b.addTranslateC` into the `sdl3_c` module.
- std and language renames: `b.args` → `addPassthruArgs()`, enum `@typeInfo` `.fields` → `.field_names`/`.field_values`, `.is_exhaustive` → `.mode`, `dupeZ` → `dupeSentinel`, `**` → `@splat`, `@intFromEnum`/`@enumFromInt` → `@backingInt`/`@fromBackingInt`.
- `minimum_zig_version`, the Dockerfile, CI, and the docs say 0.17.0. `docs/cheat_sheet.md` lists the port changes.
- Checked: `scripts/ci.sh` passes; test-tdd under Xvfb passes 98 and skips 34 of 132, the same as `main` on 0.16.0.
