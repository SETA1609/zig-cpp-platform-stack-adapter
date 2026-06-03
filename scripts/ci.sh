#!/usr/bin/env bash
# The CI gate, runnable locally — the same checks .github/workflows/build.yml
# runs (it just installs the Zig toolchain, then calls this).
#   ./scripts/ci.sh     # fmt + build + smoke demo + contract tests
set -uo pipefail
cd "$(dirname "$0")/.."

echo "== zig fmt --check =="
zig fmt --check build.zig build.zig.zon src demo || exit 1
echo "== zig build =="
zig build || exit 1
echo "== zig build run (pure-data smoke demo) =="
zig build run || exit 1
echo "== zig build test (contract) =="
zig build test || exit 1
echo "ok: all green"
