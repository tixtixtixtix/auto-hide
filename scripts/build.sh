#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild \
    -project "$ROOT/AutoHide.xcodeproj" \
    -scheme AutoHide \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$ROOT/build" \
    CODE_SIGNING_ALLOWED=NO \
    build

printf '\nBuilt: %s\n' "$ROOT/build/Build/Products/Release/Auto Hide.app"
