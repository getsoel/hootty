#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GHOSTTY_DIR="$REPO_ROOT/ghostty"
CACHE_DIR="${HOME}/.cache/hootty/ghosttykit"
VENDORS_LIB="$REPO_ROOT/Vendors/lib"
HEADERS_DIR="$REPO_ROOT/Sources/CGhostty/include"
LOCK_FILE="/tmp/hootty-setup.lock"
PATCHES_DIR="$REPO_ROOT/patches/ghostty"

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

# Check optional tools
OPTIONAL_MISSING=()
if ! command -v swiftformat &>/dev/null; then
    OPTIONAL_MISSING+=("swiftformat")
fi
if ! command -v swiftlint &>/dev/null; then
    OPTIONAL_MISSING+=("swiftlint")
fi
if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Optional (recommended): brew install ${OPTIONAL_MISSING[*]}"
fi

# --- Apply Hootty's ghostty patches ---
# Patches in patches/ghostty/ add embedder APIs upstream doesn't have yet
# (e.g. the OSC 7501 program status action). Each one is applied unless it
# already is, so re-running setup is safe.
PATCHES=()
if [ -d "$PATCHES_DIR" ]; then
    while IFS= read -r patch; do PATCHES+=("$patch"); done < <(find "$PATCHES_DIR" -name '*.patch' | sort)
fi
for patch in ${PATCHES[@]+"${PATCHES[@]}"}; do
    if git -C "$GHOSTTY_DIR" apply --reverse --check "$patch" 2>/dev/null; then
        echo "Already applied: $(basename "$patch")"
    else
        echo "Applying: $(basename "$patch")"
        git -C "$GHOSTTY_DIR" apply "$patch"
    fi
done

# --- Determine cache key (ghostty SHA + patch contents) ---
GHOSTTY_SHA="$(git -C "$GHOSTTY_DIR" rev-parse HEAD)"
CACHE_KEY="$GHOSTTY_SHA"
if [ ${#PATCHES[@]} -gt 0 ]; then
    CACHE_KEY="$GHOSTTY_SHA-$(cat "${PATCHES[@]}" | shasum | cut -c1-12)"
fi
SHA_CACHE="$CACHE_DIR/$CACHE_KEY"

echo "ghostty SHA: $GHOSTTY_SHA (cache key: $CACHE_KEY)"

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
        # The zig build may fail on the full app bundle xcodebuild step, but we
        # only need the xcframework artifact (static lib + headers).
        # Tolerate the exit code and validate the artifact below.
        zig build -Doptimize=ReleaseFast -Demit-xcframework=true -Dxcframework-target=native || true

        # Determine architecture-specific path
        ARCH="$(uname -m)"
        case "$ARCH" in
            arm64) XC_ARCH="macos-arm64" ;;
            x86_64) XC_ARCH="macos-x86_64" ;;
            *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac

        XC_DIR="$GHOSTTY_DIR/macos/GhosttyKit.xcframework/$XC_ARCH"

        # Upstream renamed libghostty-fat.a to libghostty-internal.a (2026).
        XC_LIB=""
        for name in libghostty-internal.a libghostty-fat.a; do
            if [ -f "$XC_DIR/$name" ]; then XC_LIB="$XC_DIR/$name"; break; fi
        done
        if [ -z "$XC_LIB" ]; then
            echo "Error: Build succeeded but no static library found in $XC_DIR"
            exit 1
        fi

        mkdir -p "$SHA_CACHE/headers"
        cp "$XC_LIB" "$SHA_CACHE/libghostty.a"
        cp -R "$XC_DIR/Headers/"* "$SHA_CACHE/headers/"

        # Cache themes if available
        THEMES_SRC="$GHOSTTY_DIR/zig-out/share/ghostty/themes"
        if [ -d "$THEMES_SRC" ]; then
            cp -R "$THEMES_SRC" "$SHA_CACHE/themes"
            echo "Cached $(ls "$SHA_CACHE/themes" | wc -l | tr -d ' ') theme files"
        fi

        # Cache shell-integration if available
        SHELL_INT_SRC="$GHOSTTY_DIR/zig-out/share/ghostty/shell-integration"
        if [ -d "$SHELL_INT_SRC" ]; then
            cp -R "$SHELL_INT_SRC" "$SHA_CACHE/shell-integration"
            echo "Cached shell-integration scripts"
        fi

        # Cache terminfo if available
        TERMINFO_SRC="$GHOSTTY_DIR/zig-out/share/terminfo"
        if [ -d "$TERMINFO_SRC" ]; then
            cp -R "$TERMINFO_SRC" "$SHA_CACHE/terminfo"
            echo "Cached terminfo database"
        fi

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

# --- Copy themes to SPM resources ---
THEMES_DEST="$REPO_ROOT/Sources/Hootty/Resources/Themes"
rm -rf "$THEMES_DEST"
if [ -d "$SHA_CACHE/themes" ]; then
    cp -R "$SHA_CACHE/themes" "$THEMES_DEST"
    echo "Installed $(ls "$THEMES_DEST" | wc -l | tr -d ' ') theme files to Resources/Themes/"
else
    echo "Warning: No theme files found in cache. Theme catalog will be empty."
fi

# --- Copy shell-integration to SPM resources ---
SHELL_INT_DEST="$REPO_ROOT/Sources/Hootty/Resources/shell-integration"
# hootty/ holds Hootty's own snippets (tracked in git) — replace only ghostty's.
find "$SHELL_INT_DEST" -mindepth 1 -maxdepth 1 ! -name hootty -exec rm -rf {} + 2>/dev/null || true
if [ -d "$SHA_CACHE/shell-integration" ]; then
    cp -R "$SHA_CACHE/shell-integration/." "$SHELL_INT_DEST/"
    echo "Installed shell-integration to Resources/shell-integration/"
else
    echo "Warning: No shell-integration found in cache."
fi

# --- Copy terminfo to SPM resources ---
TERMINFO_DEST="$REPO_ROOT/Sources/Hootty/Resources/terminfo"
rm -rf "$TERMINFO_DEST"
if [ -d "$SHA_CACHE/terminfo" ]; then
    cp -R "$SHA_CACHE/terminfo" "$TERMINFO_DEST"
    echo "Installed terminfo to Resources/terminfo/"
else
    echo "Warning: No terminfo found in cache."
fi

echo "Setup complete. libghostty.a installed to Vendors/lib/"
