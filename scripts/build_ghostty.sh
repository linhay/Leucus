#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY_DIR="$ROOT_DIR/ThirdParty"
GHOSTTY_DIR="$THIRD_PARTY_DIR/ghostty"
GHOSTTY_REPO_URL="${GHOSTTY_REPO_URL:-https://github.com/ghostty-org/ghostty.git}"
FRAMEWORKS_DIR="$ROOT_DIR/Frameworks"
TARGET_XCFRAMEWORK_DIR="$FRAMEWORKS_DIR/GhosttyKit.xcframework"
TARGET_RESOURCE_DIR="$ROOT_DIR/Sources/CanvasTerminalKit/Resources/ghostty"
SHIMS_DIR="$ROOT_DIR/scripts/shims"

if ! command -v zig >/dev/null 2>&1; then
  echo "error: zig is required. Install it first (or via mise)." >&2
  exit 1
fi

mkdir -p "$THIRD_PARTY_DIR"
mkdir -p "$FRAMEWORKS_DIR"

if [[ ! -d "$GHOSTTY_DIR/.git" ]]; then
  echo ">>> Cloning ghostty into ThirdParty/ghostty"
  git clone --depth 1 "$GHOSTTY_REPO_URL" "$GHOSTTY_DIR"
fi

echo ">>> Building GhosttyKit.xcframework"
(
  cd "$GHOSTTY_DIR"
  # Ghostty's macOS app target runs SwiftLint; we no-op it for framework-only builds.
  PATH="$SHIMS_DIR:$PATH" zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dsentry=false
)

echo ">>> Syncing framework to Frameworks/"
rsync -a --delete "$GHOSTTY_DIR/macos/GhosttyKit.xcframework/" "$TARGET_XCFRAMEWORK_DIR/"

if [[ -d "$GHOSTTY_DIR/zig-out/share/ghostty" ]]; then
  echo ">>> Syncing runtime resources to Sources/CanvasTerminalKit/Resources/ghostty"
  mkdir -p "$TARGET_RESOURCE_DIR"
  rsync -a --delete "$GHOSTTY_DIR/zig-out/share/ghostty/" "$TARGET_RESOURCE_DIR/"
fi

echo ">>> Done"
