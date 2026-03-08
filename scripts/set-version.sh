#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/set-version.sh <marketing-version> <build-number>
# Example: ./scripts/set-version.sh 0.1.0 42

if [ $# -lt 2 ]; then
    echo "Usage: $0 <version> <build-number>"
    echo "  version:      Marketing version (e.g., 0.1.0)"
    echo "  build-number: Build number (e.g., 42)"
    exit 1
fi

VERSION="$1"
BUILD="$2"
PLIST="$(cd "$(dirname "$0")/.." && pwd)/Sources/Hootty/Info.plist"

if [ ! -f "$PLIST" ]; then
    echo "Error: Info.plist not found at $PLIST"
    exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

echo "Set version=$VERSION build=$BUILD in $PLIST"
