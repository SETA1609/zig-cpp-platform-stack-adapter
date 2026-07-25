#!/usr/bin/env bash
# Run the gated red→green TDD suite. Optional arg = --test-filter substring.
#   ./scripts/ci/tdd.sh                   # whole suite (counts only)
#   ./scripts/ci/tdd.sh "Window.create"   # just matching tests (full output, panics shown)
# Needs a display server (X11/Wayland); for headless: SDL_VIDEODRIVER=dummy ./scripts/ci/tdd.sh
set -uo pipefail
cd "$(dirname "$0")/.."
if [ -n "${1:-}" ]; then
    zig build test-tdd --summary all -- --test-filter "$1" 2>&1
else
    zig build test-tdd --summary all 2>&1 | grep -iE "run test|build summary|error:|expected.*found|panic|failed:"
fi
