# Changelog

Last updated: 2026-11-08T04:00Z

Changes per issue, newest first. Issues are tracked in [issues.md](issues.md). An issue branch adds its entry as `changes/issue-<n>.md` (see [changes/README.md](changes/README.md)); a release branch moves the entries into a version section here. History before this file: `git log`.

## v0.7.0 (2026-11-08)

The first tagged release. It holds everything below that was unreleased (this repository's own issue tracking, Issue 7) on top of the untagged v0.1.0–v0.6.0 milestones and the v0.7.0 input, window, and mouse work in [docs/ROADMAP.md](docs/ROADMAP.md).

### Release bookkeeping

- `docs/ROADMAP.md`: a *Releases* section (issue branches add changelog fragments; bookkeeping branches edit the roadmap, the changelog, the issue statuses, and `.version`; one minor release per milestone, tagged on `main`, never moved). Milestones re-scoped so `main` is a finished v0.7.0: it holds the four input, window, and mouse steps and `getCocoaHandle`; input contexts and application paths (Issues 1 and 2) become v0.8.0; axis modifiers, injection, and loadable bindings v0.9.0; device and input/output breadth v0.10.0; renderer paths v0.11.0; audio v0.12.0.
- `changes/README.md` and `devops-tools.toml`: changelog fragments, checked and released with the shared devops-tools package.
- `build.zig.zon`: `.version` 0.7.0. `issues.md`: Issue 7 is done.

### Issue 7 Own issue tracking

- `issues.md` lists the Zig 0.17.0 work as this repo's own issues; changelog entries are titled by those issues.
- Docs and the changelog no longer refer to other projects' issue IDs.

## 2026-10-28

### Issue 6 Docs after the 0.17.0 port (#7)

- `README.md`: a Development section for the CI gate, the container CLI, and this changelog; `tools/devops/README.md` in the Documentation list.
- This changelog: entries carry their PR numbers.

### Issue 5 Container devops CLI for contributors (#6)

- Add `.zig-version` (`0.17.0`), checked against `ARG ZIG_VERSION` in the `Dockerfile`.
- Add `tools/devops/`, a host-side Python CLI (uv; standard library only at runtime). It runs the toolchain container with every output line timestamped and logged to `cache/logs/`.
- One shim: `./scripts/container.sh <subcommand>` with `image`, `build`, `test`, `zig`, `ci` (runs `scripts/ci.sh`), `tdd` (`zig build test-tdd` under Xvfb with software GL), `shell`, `prune`, and `clean`.
- A leading `--keep-cache` keeps the Zig global cache in the volume `platform-stack-adapter-zig-cache` until `clean`.
- Containers run with `--init`. Without it `xvfb-run` is PID 1 and never sees Xvfb's ready signal, so `tdd` hangs.
- The `Dockerfile` installs the Mesa GL and Vulkan runtime (`libgl1-mesa-dri`, `libglx-mesa0`, `libvulkan1`, `mesa-vulkan-drivers`), as `scripts/install_display_deps.py` does in CI. Without them 4 Vulkan hand-off tests fail.
- `scripts/ci.sh` and `scripts/tdd.sh` are unchanged and still run without a container.
- Checked: `container.sh ci` passes; `container.sh tdd` passes 98 and skips 34 of 132.

### Issue 4 Port to Zig 0.17.0 (#5)

- castholm/SDL `v0.5.0+3.4.8` → `v0.6.0+3.4.18`, which targets 0.17.0.
- `@cImport` is removed in 0.17: the SDL includes are in `src/backend/sdl3_c.h`, translated by `b.addTranslateC` into the `sdl3_c` module.
- std and language renames: `b.args` → `addPassthruArgs()`, enum `@typeInfo` `.fields` → `.field_names`/`.field_values`, `.is_exhaustive` → `.mode`, `dupeZ` → `dupeSentinel`, `**` → `@splat`, `@intFromEnum`/`@enumFromInt` → `@backingInt`/`@fromBackingInt`.
- `minimum_zig_version`, the Dockerfile, CI, and the docs say 0.17.0. `docs/cheat_sheet.md` lists the port changes.
- Checked: `scripts/ci.sh` passes; test-tdd under Xvfb passes 98 and skips 34 of 132, the same as `main` on 0.16.0.
