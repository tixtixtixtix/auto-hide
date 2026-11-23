#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/checks"
swiftc -swift-version 5 -parse-as-library \
    "$ROOT/Sources/Core/Preferences.swift" \
    "$ROOT/Sources/Core/FocusScheduler.swift" \
    "$ROOT/Sources/App/PreferencesStore.swift" \
    "$ROOT/Sources/App/AutoHideService.swift" \
    "$ROOT/Sources/App/SettingsView.swift" \
    "$ROOT/scripts/SettingsSmokeTest.swift" \
    -o "$ROOT/build/checks/settings-smoke"
"$ROOT/build/checks/settings-smoke" "$ROOT/build/checks"
