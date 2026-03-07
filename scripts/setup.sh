#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GHOSTTY_DIR="$REPO_ROOT/ghostty"
CACHE_DIR="${HOME}/.cache/hootty/ghosttykit"
VENDORS_LIB="$REPO_ROOT/Vendors/lib"
HEADERS_DIR="$REPO_ROOT/Sources/CGhostty/include"
LOCK_FILE="/tmp/hootty-setup.lock"

# --- Git hooks ---
git -C "$REPO_ROOT" config core.hooksPath .githooks

# --- Submodule ---
echo "Initializing ghostty submodule..."
git -C "$REPO_ROOT" submodule update --init --recursive

# --- Check dependencies ---
MISSING=()
if ! command -v zig &>/dev/null; then
    MISSING+=("zig (brew install zig or https://ziglang.org/download/)")
fi
if ! command -v msgfmt &>/dev/null; then
    MISSING+=("gettext (brew install gettext)")
fi
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Error: missing required tools:"
    for dep in "${MISSING[@]}"; do echo "  - $dep"; done
    exit 1
fi

# --- Determine ghostty SHA for caching ---
GHOSTTY_SHA="$(git -C "$GHOSTTY_DIR" rev-parse HEAD)"
SHA_CACHE="$CACHE_DIR/$GHOSTTY_SHA"

echo "ghostty SHA: $GHOSTTY_SHA"

# --- Build or use cache ---
if [ -f "$SHA_CACHE/libghostty.a" ]; then
    echo "Using cached build from $SHA_CACHE"
else
    echo "No cached build found. Building libghostty (this takes a while)..."

    # Filesystem lock to prevent parallel builds (mkdir is atomic on POSIX)
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        echo "Another build is in progress. Waiting..."
        while ! mkdir "$LOCK_FILE" 2>/dev/null; do sleep 1; done
    fi
    trap 'rmdir "$LOCK_FILE" 2>/dev/null' EXIT

    # Re-check cache after acquiring lock (another process may have built it)
    if [ ! -f "$SHA_CACHE/libghostty.a" ]; then
        cd "$GHOSTTY_DIR"
        zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dxcframework-target=native

        # Determine architecture-specific path
        ARCH="$(uname -m)"
        case "$ARCH" in
            arm64) XC_ARCH="macos-arm64" ;;
            x86_64) XC_ARCH="macos-x86_64" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac

        XC_DIR="$GHOSTTY_DIR/macos/GhosttyKit.xcframework/$XC_ARCH"

        if [ ! -f "$XC_DIR/libghostty-fat.a" ]; then
            echo "Error: Build succeeded but expected output not found at $XC_DIR/libghostty-fat.a"
            exit 1
        fi

        mkdir -p "$SHA_CACHE/headers"
        cp "$XC_DIR/libghostty-fat.a" "$SHA_CACHE/libghostty.a"
        cp -R "$XC_DIR/Headers/"* "$SHA_CACHE/headers/"

        echo "Cached build at $SHA_CACHE"
    else
        echo "Cache was populated by another process."
    fi

    rmdir "$LOCK_FILE" 2>/dev/null
    trap - EXIT
fi

# --- Copy artifacts ---
mkdir -p "$VENDORS_LIB"
cp "$SHA_CACHE/libghostty.a" "$VENDORS_LIB/libghostty.a"
# Copy headers but preserve the existing CGhostty module.modulemap
cp "$SHA_CACHE/headers/ghostty.h" "$HEADERS_DIR/"
cp -R "$SHA_CACHE/headers/ghostty" "$HEADERS_DIR/"

echo "Setup complete. libghostty.a installed to Vendors/lib/"
