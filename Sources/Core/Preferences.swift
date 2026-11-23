import Foundation

struct AppRule: Codable, Equatable, Identifiable {
    var bundleIdentifier: String
    var name: String
    var path: String?
    var customDelay: Double?
    var neverHide = false
    var ignoreFocus = false

    var id: String { bundleIdentifier }
}

struct Preferences: Codable, Equatable {
    static let maximumDelay: Double = 86_400

    var defaultDelay: Double = 10
    var rules: [AppRule] = [
        AppRule(
            bundleIdentifier: "com.apple.finder",
            name: "Finder",
            path: "/System/Library/CoreServices/Finder.app",
            neverHide: true,
            ignoreFocus: true
        )
    ]

    func delay(for bundleIdentifier: String) -> Double? {
        let rule = rules.first { $0.bundleIdentifier == bundleIdentifier }
        guard rule?.neverHide != true else { return nil }
        return Self.validDelay(rule?.customDelay ?? defaultDelay)
    }

    func ignoresFocus(of bundleIdentifier: String) -> Bool {
        rules.first { $0.bundleIdentifier == bundleIdentifier }?.ignoreFocus ?? false
    }

    static func validDelay(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), maximumDelay) : 10
    }

    mutating func normalize() {
        defaultDelay = Self.validDelay(defaultDelay)
        var seen = Set<String>()
        rules = rules.filter { !$0.bundleIdentifier.isEmpty && seen.insert($0.id).inserted }
        for index in rules.indices {
            if let delay = rules[index].customDelay {
                rules[index].customDelay = Self.validDelay(delay)
            }
        }
    }
}
