#!/usr/bin/env bash
# Run bats tests (downloads bats-core to .cache/ if bats is not installed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ensure_bats() {
  if command -v bats >/dev/null 2>&1; then
    BATS_BIN="$(command -v bats)"
    return
  fi

  local version="v1.11.1"
  local cache_dir="$ROOT/.cache/bats-core"
  local bin="$cache_dir/bin/bats"

  if [[ -x "$bin" ]]; then
    BATS_BIN="$bin"
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "test: bats is required (e.g. apt install bats) or install git to auto-download." >&2
    exit 1
  fi

  echo "test: downloading bats-core ${version}..." >&2
  rm -rf "$cache_dir"
  git clone --depth 1 --branch "$version" \
    https://github.com/bats-core/bats-core.git "$cache_dir"
  BATS_BIN="$bin"
}

ensure_bats
"$BATS_BIN" tests/
