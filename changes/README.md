# Changelog fragments

Each issue branch adds one file here, named after its issue: `changes/issue-<n>.md`, for example `changes/issue-8.md` on the branch `issue-8-implement-input-contexts`. The file is that issue's changelog entry:

```markdown
### issue-8 Implement input contexts

- `pushContext` / `popContext` / `replaceTopContext` / `activeContext` / `isContextActive` are implemented; an action bound in a context fires only while that context is active.
- Checked: `zig build test` and the display suite under Xvfb (a virtual X11 display) pass.
```

Rules, checked by the shared [devops-tools](https://github.com/SETA1609/devops_tools) package (`devops-tools changelog-fragments --settings-file devops-tools.toml check`):

- The file name is the issue ID, `issue-<n>`, plus `.md`, with the number from [issues.md](../issues.md).
- The first line is `### issue-<n> <title>`, with the same issue ID.
- At least one `- ` bullet follows. No other headings, no `Last updated:` line, no `Status:` line.

An issue branch does not edit [CHANGELOG.md](../CHANGELOG.md), [docs/ROADMAP.md](../docs/ROADMAP.md), the statuses in [issues.md](../issues.md), or `.version`, so open branches do not conflict on them. A bookkeeping branch makes those edits; see *Releases* in [docs/ROADMAP.md](../docs/ROADMAP.md).

## Releasing

On an up-to-date `main`, in a branch `release-vX.Y.Z`:

```sh
devops-tools changelog-fragments --settings-file devops-tools.toml preview
devops-tools changelog-fragments --settings-file devops-tools.toml release --section-title "vX.Y.Z (yyyy-mm-dd)"
```

`release` moves every fragment into a new `## vX.Y.Z (yyyy-mm-dd)` section at the top of `CHANGELOG.md`, adds ` (#N)` from the squash-merge commit that added each fragment, deletes the fragments, and updates `Last updated:`. The same branch marks the milestone released in the roadmap, sets the closed issues to `done`, and sets `.version` in `build.zig.zon`. After it merges, tag the merge commit `vX.Y.Z` on `main` and push the tag.
