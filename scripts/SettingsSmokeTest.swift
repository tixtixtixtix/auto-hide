import AppKit
import SwiftUI

/// Render the real settings without activating or hiding any applications.
/// Compile using scripts/check-settings.sh; output stays in the ignored build folder.
@main
struct SettingsSmokeTest {
    @MainActor
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let suite = "app.autohide.settings-smoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let service = AutoHideService(store: store)
        service.isPaused = true
        defer { service.stop() }

        // Exercise persistence through the production store, not a test double.
        store.preferences.defaultDelay = 2.5
        store.updateRule("com.apple.finder") { $0.customDelay = 0 }
        let restored = PreferencesStore(defaults: defaults)
        precondition(restored.preferences == store.preferences, "Preferences did not persist")
        store.preferences.defaultDelay = 10

        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 720, height: 500),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        let view = NSHostingView(rootView: SettingsView(store: store, service: service))
        view.frame = NSRect(x: 0, y: 0, width: 720, height: 500)
        window.contentView = view
        window.orderBack(nil)
        defer { window.orderOut(nil) }

        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                fatalError("Could not allocate settings snapshot")
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                fatalError("Could not encode settings snapshot")
            }
            try data.write(to: output.appendingPathComponent("settings-\(name).png"))
        }
        print("Settings rendered in light and dark mode; persistence smoke test passed.")
    }
}
