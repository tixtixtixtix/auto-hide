import XCTest
@testable import AutoHideCore

final class FocusSchedulerTests: XCTestCase {
    private let appA = "example.A"
    private let appB = "example.B"
    private let appC = "example.C"
    private let finder = "com.apple.finder"

    func testInitialActivationDoesNotHideAnything() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        XCTAssertEqual(scheduler.lastMeaningfulApp, appA)
        XCTAssertNil(scheduler.nextDeadline)
    }

    func testDefaultDelayAndDueBoundary() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 5, preferences: Preferences())
        XCTAssertEqual(scheduler.nextDeadline, 15)
        XCTAssertTrue(scheduler.takeDue(at: 14.999).isEmpty)
        XCTAssertEqual(scheduler.takeDue(at: 15), [appA])
        XCTAssertNil(scheduler.nextDeadline)
    }

    func testZeroDelayIsImmediatelyDue() {
        var preferences = Preferences()
        preferences.defaultDelay = 0
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 20, preferences: preferences)
        scheduler.activate(appB, at: 20, preferences: preferences)
        XCTAssertEqual(scheduler.takeDue(at: 20), [appA])
    }

    func testPerAppDelayOverridesDefault() {
        var preferences = Preferences()
        preferences.rules.append(AppRule(bundleIdentifier: appA, name: "A", customDelay: 2.5))
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: preferences)
        scheduler.activate(appB, at: 10, preferences: preferences)
        XCTAssertEqual(scheduler.nextDeadline, 12.5)
    }

    func testReturningToAppCancelsItsCountdown() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.activate(appA, at: 2, preferences: Preferences())
        XCTAssertNil(scheduler.deadlines[appA])
        XCTAssertEqual(scheduler.deadlines[appB], 12)
    }

    func testRapidSwitchesKeepIndependentDeadlines() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.activate(appC, at: 2, preferences: Preferences())
        XCTAssertEqual(scheduler.nextDeadline, 11)
        XCTAssertEqual(scheduler.takeDue(at: 11), [appA])
        XCTAssertEqual(scheduler.nextDeadline, 12)
        XCTAssertEqual(scheduler.takeDue(at: 12), [appB])
    }

    func testNeverHideAppStillTriggersPreviousAppCountdown() {
        var preferences = Preferences()
        preferences.rules.append(AppRule(bundleIdentifier: appB, name: "B", neverHide: true))
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: preferences)
        scheduler.activate(appB, at: 1, preferences: preferences)
        scheduler.activate(appC, at: 2, preferences: preferences)
        XCTAssertEqual(scheduler.deadlines[appA], 11)
        XCTAssertNil(scheduler.deadlines[appB])
    }

    func testFinderFocusIsTransparent() {
        let preferences = Preferences()
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: preferences)
        scheduler.activate(finder, at: 1, preferences: preferences)
        XCTAssertEqual(scheduler.lastMeaningfulApp, appA)
        XCTAssertNil(scheduler.nextDeadline)
        scheduler.activate(appB, at: 5, preferences: preferences)
        XCTAssertEqual(scheduler.deadlines[appA], 15)
        XCTAssertNil(scheduler.deadlines[finder])
    }

    func testIgnoredFocusDoesNotCancelOtherAppsCountdowns() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.activate(finder, at: 2, preferences: Preferences())
        XCTAssertEqual(scheduler.deadlines[appA], 11)
        XCTAssertNil(scheduler.deadlines[appB])
    }

    func testReturnThroughFinderDoesNotHideOriginalApp() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(finder, at: 1, preferences: Preferences())
        scheduler.activate(appA, at: 2, preferences: Preferences())
        XCTAssertNil(scheduler.nextDeadline)
    }

    func testIgnoredFocusAppCanStillBeHiddenWhenSwitchingAway() {
        var preferences = Preferences()
        preferences.rules.append(AppRule(bundleIdentifier: appB, name: "B", ignoreFocus: true))
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: preferences)
        scheduler.activate(appB, at: 1, preferences: preferences)
        XCTAssertNil(scheduler.nextDeadline)
        scheduler.activate(appC, at: 2, preferences: preferences)
        XCTAssertEqual(scheduler.deadlines[appA], 12)
        XCTAssertEqual(scheduler.deadlines[appB], 12)
    }

    func testReturningFromIgnoredAppOnlySchedulesIgnoredApp() {
        var preferences = Preferences()
        preferences.rules.append(AppRule(bundleIdentifier: appB, name: "B", ignoreFocus: true))
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: preferences)
        scheduler.activate(appB, at: 1, preferences: preferences)
        scheduler.activate(appA, at: 2, preferences: preferences)
        XCTAssertNil(scheduler.deadlines[appA])
        XCTAssertEqual(scheduler.deadlines[appB], 12)
    }

    func testSeveralIgnoredAppsPreserveIndependentHidingRules() {
        let ignored = "example.ignored"
        var preferences = Preferences()
        preferences.rules.append(AppRule(bundleIdentifier: appB, name: "B", ignoreFocus: true))
        preferences.rules.append(AppRule(bundleIdentifier: ignored, name: "Ignored", ignoreFocus: true))
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: preferences)
        scheduler.activate(appB, at: 1, preferences: preferences)
        scheduler.activate(ignored, at: 2, preferences: preferences)
        scheduler.activate(appC, at: 3, preferences: preferences)
        XCTAssertEqual(Set(scheduler.takeDue(at: 13)), Set([appA, appB, ignored]))
    }

    func testRepeatedActivationDoesNotRestartCountdown() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.activate(appB, at: 5, preferences: Preferences())
        XCTAssertEqual(scheduler.deadlines[appA], 11)
    }

    func testMultipleOverdueAppsAreDrainedOnce() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.activate(appC, at: 2, preferences: Preferences())
        XCTAssertEqual(Set(scheduler.takeDue(at: 100)), Set([appA, appB]))
        XCTAssertTrue(scheduler.takeDue(at: 100).isEmpty)
    }

    func testTerminatedAppIsRemovedFromTracking() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.remove(appA)
        XCTAssertNil(scheduler.nextDeadline)
        scheduler.remove(appB)
        XCTAssertNil(scheduler.lastMeaningfulApp)
    }

    func testResetClearsAllTrackingForPauseOrSleep() {
        var scheduler = FocusScheduler()
        scheduler.activate(appA, at: 0, preferences: Preferences())
        scheduler.activate(appB, at: 1, preferences: Preferences())
        scheduler.reset()
        XCTAssertNil(scheduler.lastMeaningfulApp)
        XCTAssertNil(scheduler.nextDeadline)
        scheduler.activate(appC, at: 50, preferences: Preferences())
        XCTAssertNil(scheduler.nextDeadline)
    }
}
