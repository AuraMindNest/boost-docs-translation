#!/usr/bin/env bash
# Run ShellCheck and actionlint (same checks as CI lint job).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ensure_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_BIN="$(command -v shellcheck)"
    return
  fi

  local version="v0.11.0"
  local cache_dir="$ROOT/.cache/shellcheck"
  local bin="$cache_dir/shellcheck"
  mkdir -p "$cache_dir"

  if [[ -x "$bin" ]]; then
    SHELLCHECK_BIN="$bin"
    return
  fi

  local os arch tarball url
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Linux)
      case "$arch" in
        x86_64) tarball="shellcheck-${version}.linux.x86_64.tar.xz" ;;
        aarch64|arm64) tarball="shellcheck-${version}.linux.aarch64.tar.xz" ;;
        *)
          echo "lint: unsupported Linux architecture for shellcheck download: $arch" >&2
          echo "lint: install shellcheck manually (e.g. apt install shellcheck)." >&2
          exit 1
          ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64) tarball="shellcheck-${version}.darwin.x86_64.tar.xz" ;;
        arm64) tarball="shellcheck-${version}.darwin.aarch64.tar.xz" ;;
        *)
          echo "lint: unsupported macOS architecture for shellcheck download: $arch" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "lint: shellcheck not found and auto-download unsupported on $os." >&2
      echo "lint: install shellcheck manually (e.g. apt install shellcheck)." >&2
      exit 1
      ;;
  esac

  url="https://github.com/koalaman/shellcheck/releases/download/${version}/${tarball}"
  if [[ ! -f "$cache_dir/$tarball" ]]; then
    echo "lint: downloading shellcheck ${version}..." >&2
    curl -fsSL -o "$cache_dir/$tarball" "$url"
  fi
  if [[ ! -d "$cache_dir/shellcheck-${version}" ]]; then
    if ! tar -xJf "$cache_dir/$tarball" -C "$cache_dir"; then
      echo "lint: failed to extract shellcheck (is xz installed? apt install xz-utils)." >&2
      exit 1
    fi
  fi
  cp "$cache_dir/shellcheck-${version}/shellcheck" "$bin"
  chmod +x "$bin"
  SHELLCHECK_BIN="$bin"
}

ensure_shellcheck

"$SHELLCHECK_BIN" -x \
  .github/workflows/assets/env.sh \
  .github/workflows/assets/lib.sh \
  .github/workflows/assets/translation.sh \
  scripts/*.sh \
  tests/helpers/*.bash

ACTIONLINT_VERSION="1.7.7"
ACTIONLINT_SHA256="023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757"
CACHE_DIR="$ROOT/.cache/actionlint"
ACTIONLINT_BIN="$CACHE_DIR/actionlint"
mkdir -p "$CACHE_DIR"

if [[ ! -x "$ACTIONLINT_BIN" ]]; then
  os="$(uname -s)"
  case "$os" in
    Darwin) tarball="actionlint_${ACTIONLINT_VERSION}_darwin_amd64.tar.gz" ;;
    Linux) tarball="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz" ;;
    *)
      echo "lint: unsupported OS for actionlint download: $os" >&2
      exit 1
      ;;
  esac
  curl -fsSL -o "$CACHE_DIR/$tarball" \
    "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${tarball}"
  if [[ "$os" == "Linux" ]]; then
    echo "${ACTIONLINT_SHA256}  $CACHE_DIR/$tarball" | sha256sum -c -
  fi
  tar -xzf "$CACHE_DIR/$tarball" -C "$CACHE_DIR"
fi

"$ACTIONLINT_BIN" -color
