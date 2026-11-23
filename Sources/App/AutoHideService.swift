import AppKit
import Combine

@MainActor
final class AutoHideService: ObservableObject {
    @Published var isPaused = false {
        didSet { resetTracking() }
    }

    private let store: PreferencesStore
    private var scheduler = FocusScheduler()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var preferencesSubscription: AnyCancellable?
    private var isSleeping = false
    private var isScreenLocked = false
    private var isStopped = false
    private let ownIdentifier = Bundle.main.bundleIdentifier

    init(store: PreferencesStore) {
        self.store = store
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.activated(app) }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication, let id = app.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                // Another process with the same bundle ID may still be alive.
                guard NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty else { return }
                self?.scheduler.remove(id)
                self?.scheduleNextDeadline()
            }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isSleeping = true
                self?.resetTracking()
            }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isSleeping = false
                self?.resetTracking()
            }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isScreenLocked = true
                self?.resetTracking()
            }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isScreenLocked = false
                self?.resetTracking()
            }
        })

        // Apply edited rules prospectively, discarding deadlines made under old rules.
        preferencesSubscription = store.$preferences.dropFirst().sink { [weak self] _ in
            // @Published emits before the value changes; reset after the edit completes.
            Task { @MainActor [weak self] in self?.resetTracking() }
        }
        resetTracking()
    }

    private var isEnabled: Bool { !isPaused && !isSleeping && !isScreenLocked && !isStopped }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func activated(_ app: NSRunningApplication) {
        guard isEnabled, app.activationPolicy == .regular,
              let id = app.bundleIdentifier, id != ownIdentifier else { return }
        scheduler.activate(id, at: now, preferences: store.preferences)
        hideDueApplications()
    }

    private func resetTracking() {
        timer?.invalidate()
        timer = nil
        scheduler.reset()
        if isEnabled, let app = NSWorkspace.shared.frontmostApplication {
            activated(app)
        }
    }

    private func hideDueApplications() {
        guard isEnabled else { return }
        for id in scheduler.takeDue(at: now) {
            guard id != ownIdentifier, store.preferences.delay(for: id) != nil else { continue }
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) {
                // Re-check immediately before each hide, not just when the timer was set.
                guard !app.isActive, !app.isHidden, !app.isTerminated,
                      app.activationPolicy == .regular,
                      NSWorkspace.shared.frontmostApplication?.bundleIdentifier != id else { continue }
                app.hide()
            }
        }
        scheduleNextDeadline()
    }

    private func scheduleNextDeadline() {
        timer?.invalidate()
        timer = nil
        guard isEnabled, let deadline = scheduler.nextDeadline else { return }
        let interval = max(0, deadline - now)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideDueApplications() }
        }
        timer.tolerance = min(0.1, interval * 0.05)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        isStopped = true
        scheduler.reset()
        timer?.invalidate()
        timer = nil
        preferencesSubscription?.cancel()
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }
}
