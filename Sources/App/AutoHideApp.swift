import AppKit
import SwiftUI

private enum SettingsWindow {
    static let id = "settings"
}

@main
struct AutoHideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store: PreferencesStore
    @StateObject private var service: AutoHideService
    @Environment(\.openWindow) private var openWindow

    init() {
        let store = PreferencesStore()
        _store = StateObject(wrappedValue: store)
        _service = StateObject(wrappedValue: AutoHideService(store: store))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(service: service)
        } label: {
            Image(systemName: service.isPaused ? "eye" : "eye.slash")
                .accessibilityLabel(service.isPaused ? "Auto Hide, paused" : "Auto Hide")
        }
        .menuBarExtraStyle(.menu)

        Window("Auto Hide Settings", id: SettingsWindow.id) {
            SettingsView(store: store, service: service)
        }
        .defaultSize(width: 720, height: 500)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…", systemImage: "gearshape") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: SettingsWindow.id)
                }
                .keyboardShortcut(",")
            }
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var service: AutoHideService
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(service.isPaused ? "Auto Hide · Paused" : "Auto Hide · Active")
        Divider()
        Button(
            service.isPaused ? "Resume Auto Hide" : "Pause Auto Hide",
            systemImage: service.isPaused ? "play.circle" : "pause.circle"
        ) {
            service.isPaused.toggle()
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        Divider()
        Button("Settings…", systemImage: "gearshape") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: SettingsWindow.id)
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Auto Hide", systemImage: "power") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool { false }
    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool { false }
}
