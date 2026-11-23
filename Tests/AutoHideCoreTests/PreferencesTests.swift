import XCTest
@testable import AutoHideCore

final class PreferencesTests: XCTestCase {
    func testDefaultsProtectFinder() {
        let preferences = Preferences()
        XCTAssertNil(preferences.delay(for: "com.apple.finder"))
        XCTAssertTrue(preferences.ignoresFocus(of: "com.apple.finder"))
        XCTAssertEqual(preferences.delay(for: "example.app"), 10)
        XCTAssertFalse(preferences.ignoresFocus(of: "example.app"))
    }

    func testFocusAndHideExclusionsAreIndependent() {
        let preferences = Preferences(rules: [
            AppRule(bundleIdentifier: "ignored", name: "Ignored", ignoreFocus: true),
            AppRule(bundleIdentifier: "excluded", name: "Excluded", neverHide: true)
        ])
        XCTAssertEqual(preferences.delay(for: "ignored"), 10)
        XCTAssertTrue(preferences.ignoresFocus(of: "ignored"))
        XCTAssertNil(preferences.delay(for: "excluded"))
        XCTAssertFalse(preferences.ignoresFocus(of: "excluded"))
    }

    func testInvalidDelaysAreClamped() {
        XCTAssertEqual(Preferences.validDelay(-5), 0)
        XCTAssertEqual(Preferences.validDelay(0), 0)
        XCTAssertEqual(Preferences.validDelay(0.25), 0.25)
        XCTAssertEqual(Preferences.validDelay(100_000), 86_400)
        XCTAssertEqual(Preferences.validDelay(.nan), 10)
        XCTAssertEqual(Preferences.validDelay(.infinity), 10)
    }

    func testNormalizationRemovesDuplicatesAndInvalidIdentifiers() {
        var preferences = Preferences(defaultDelay: -1, rules: [
            AppRule(bundleIdentifier: "a", name: "A", customDelay: -10),
            AppRule(bundleIdentifier: "a", name: "Duplicate"),
            AppRule(bundleIdentifier: "", name: "Invalid")
        ])
        preferences.normalize()
        XCTAssertEqual(preferences.defaultDelay, 0)
        XCTAssertEqual(preferences.rules.count, 1)
        XCTAssertEqual(preferences.rules[0].customDelay, 0)
    }

    func testPreferencesRoundTrip() throws {
        let preferences = Preferences(defaultDelay: 3.5, rules: [
            AppRule(bundleIdentifier: "a", name: "App A", path: "/Applications/A.app", customDelay: 0),
            AppRule(bundleIdentifier: "b", name: "App B", neverHide: true, ignoreFocus: true)
        ])
        let data = try JSONEncoder().encode(preferences)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: data), preferences)
    }
}
