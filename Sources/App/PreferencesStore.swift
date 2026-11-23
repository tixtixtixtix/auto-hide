import AppKit
import Combine

@MainActor
final class PreferencesStore: ObservableObject {
    private static let storageKey = "app.auto-hide.preferences.v1"
    private let defaults: UserDefaults

    @Published var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: Self.storageKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           var decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            decoded.normalize()
            preferences = decoded
        } else {
            preferences = Preferences()
        }
    }

    func addApplication(at url: URL) -> String? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              identifier != Bundle.main.bundleIdentifier else { return nil }
        if !preferences.rules.contains(where: { $0.id == identifier }) {
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            preferences.rules.append(AppRule(
                bundleIdentifier: identifier,
                name: name,
                path: url.path
            ))
        }
        return identifier
    }

    func removeRule(_ identifier: String) {
        preferences.rules.removeAll { $0.id == identifier }
    }

    func updateRule(_ identifier: String, _ update: (inout AppRule) -> Void) {
        guard let index = preferences.rules.firstIndex(where: { $0.id == identifier }) else { return }
        var rule = preferences.rules[index]
        update(&rule)
        if let delay = rule.customDelay { rule.customDelay = Preferences.validDelay(delay) }
        preferences.rules[index] = rule
    }
}
