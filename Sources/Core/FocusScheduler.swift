import Foundation

/// Pure scheduling state. The host supplies a monotonic clock and performs hides.
struct FocusScheduler {
    private(set) var lastMeaningfulApp: String?
    private(set) var deadlines: [String: TimeInterval] = [:]
    private var lastFocusedApp: String?
    private var deferredApps = Set<String>()

    var nextDeadline: TimeInterval? { deadlines.values.min() }

    mutating func activate(_ app: String, at now: TimeInterval, preferences: Preferences) {
        // An app must never retain a countdown after regaining focus, even if its
        // focus is otherwise ignored.
        deadlines.removeValue(forKey: app)
        deferredApps.remove(app)
        if let previous = lastFocusedApp, previous != app {
            deferredApps.insert(previous)
        }
        lastFocusedApp = app
        guard !preferences.ignoresFocus(of: app) else { return }

        // Defer focus-triggered hides while visiting ignored apps, then apply
        // each app's independent hiding policy on the next meaningful switch.
        for previous in deferredApps {
            if let delay = preferences.delay(for: previous), deadlines[previous] == nil {
                deadlines[previous] = now + delay
            }
        }
        deferredApps.removeAll()
        lastMeaningfulApp = app
    }

    mutating func takeDue(at now: TimeInterval) -> [String] {
        let due = deadlines.filter { $0.value <= now }.map(\.key).sorted()
        for app in due { deadlines.removeValue(forKey: app) }
        return due
    }

    mutating func remove(_ app: String) {
        deadlines.removeValue(forKey: app)
        deferredApps.remove(app)
        if lastMeaningfulApp == app { lastMeaningfulApp = nil }
        if lastFocusedApp == app { lastFocusedApp = nil }
    }

    mutating func reset() {
        deadlines.removeAll()
        lastMeaningfulApp = nil
        lastFocusedApp = nil
        deferredApps.removeAll()
    }
}
