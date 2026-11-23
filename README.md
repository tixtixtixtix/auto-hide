# Auto Hide

A lightweight, native macOS menu bar app that hides applications after you switch away. Built with Swift, SwiftUI, and AppKit. Requires **macOS 14 or later**; supports Apple Silicon and Intel.

## Build and run

Requires **Xcode 16 or later**, selected as the active developer directory.

```sh
bash scripts/build.sh
open "build/Build/Products/Release/Auto Hide.app"
```

Or open `AutoHide.xcodeproj`, select the **AutoHide** scheme, and run. For local Xcode builds, choose **Sign to Run Locally** in Signing & Capabilities if needed. The build script does not require a signing team. A distributed release should be Developer ID signed and notarized.

Click the overlapping-windows icon in the menu bar and choose **Settings…**. Auto Hide has no Dock icon and keeps running when settings close. Choose **Pause Auto Hide** to suspend hiding, or **Quit Auto Hide** to exit. Pause lasts for the current session.

## Rules

- **Default delay:** Apps without a rule hide after 10 seconds by default. Set any delay from **0 to 86,400 seconds**, including fractional seconds. **0 hides immediately** after a qualifying switch.
- **Custom delay:** Add an app using **+**, choosing a running app or browsing for an `.app` bundle. Each app can override the default delay.
- **Never hide:** The app stays visible when inactive. Switching to it still starts countdowns for other apps unless its focus is also ignored.
- **Ignore when switching focus:** Visiting this app does not start countdowns for apps you leave. On the next non-ignored focus switch, deferred apps begin their respective countdowns. Existing countdowns continue. This does **not** imply “Never hide”; enable both if desired.
- **Finder:** Both “Never hide” and “Ignore when switching focus” are enabled initially. Switching from app A to Finder does not start A’s countdown; switching next to app B does.
- **Remove a rule:** Select it and click **−**. The app returns to the default behavior; it is not excluded.

Returning to an app cancels its countdown. Multiple inactive apps can have independent countdowns. Auto Hide never hides the foreground app or itself. It hides entire apps using macOS’s normal Hide operation, not individual windows; windows and documents remain open. It does not unhide apps automatically. Apps are only considered after they participate in focus switches, not retroactively at launch.

Settings persist locally and take effect immediately. Changing rules, pausing/resuming, sleeping/waking, or switching user sessions clears existing countdowns and starts fresh tracking. Apps without a bundle identifier, background agents, and accessory-only apps are not tracked. Full-screen windows and Spaces follow macOS’s standard app-hiding behavior; Auto Hide does not force Space transitions or retry hides that macOS declines.

## Resource use and privacy

- `NSWorkspace` notifications drive focus tracking—**no polling**.
- One non-repeating timer targets the earliest outstanding deadline; no scheduled timer when idle or paused.
- `NSRunningApplication.hide()` performs native hiding. No window enumeration, screenshots, global input hooks, or continuous rendering.
- The hidden settings window has no animations or periodic updates. Native app icons are loaded only for configuration UI.
- No Accessibility, Screen Recording, or Full Disk Access permissions. No network requests, analytics, external packages, or background helpers.
- Rules are stored in `UserDefaults` under `app.auto-hide.preferences.v1` in the `app.autohide.AutoHide` application domain.

Actual memory and energy use depend on macOS and SwiftUI. To profile, run the Release scheme with Instruments (Allocations / Time Profiler / Energy Log), leave settings closed, and compare idle and focus-switching periods.

## Checks

```sh
swift test
bash scripts/check-settings.sh
```

The tests cover delay boundaries, immediate hiding, independent countdowns, returning to an app, exclusions, ignored-focus chains, termination, reset behavior, and preference validation/serialization. The settings smoke test checks production preference persistence and renders the real settings view in light/dark appearances to `build/checks/`, without activating or hiding any applications. It requires a logged-in graphical macOS session.

For a manual end-to-end check, use two disposable apps: set a short delay for A, switch A → B, and verify A hides but its windows remain. Repeat with 0 seconds, return to A before the deadline, enable “Never hide,” and try A → Finder → B. Confirm pause cancels pending hides and that menu/settings work in both appearances. Live cross-app hiding, full-screen/Spaces behavior, and real-world resource use require these interactive checks.

## Layout

```text
Sources/Core/          Pure preferences and focus/deadline scheduler
Sources/App/           Workspace notifications, persistence, SwiftUI settings/menu
Sources/Assets.xcassets/ Native app icon
Resources/Info.plist    Menu-bar-only app configuration
Tests/                 Dependency-free Swift Package core tests
scripts/               Build, settings smoke test, and icon generation
```

The Xcode app compiles the core sources directly. `Package.swift` exposes those same sources to the unit tests without launching the app. Icon PNGs are checked in; regenerate with `swift scripts/GenerateIcon.swift Sources/Assets.xcassets/AppIcon.appiconset`.
