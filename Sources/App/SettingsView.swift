import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsSidebarItem: Hashable, Sendable {
    case general
    case rule(String)
}

struct SettingsView: View {
    @ObservedObject var store: PreferencesStore
    @ObservedObject var service: AutoHideService
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selection: SettingsSidebarItem?
    @State private var backStack: [SettingsSidebarItem] = []
    @State private var forwardStack: [SettingsSidebarItem] = []
    @State private var isNavigatingHistory = false
    @State private var addError: String?
    @State private var addMenuController = AddRuleMenuController()
    @FocusState private var isSidebarFocused: Bool

    init(
        store: PreferencesStore,
        service: AutoHideService,
        initialSelection: SettingsSidebarItem = .general
    ) {
        self.store = store
        self.service = service
        _selection = State(initialValue: initialSelection)
    }

    private var sortedRules: [AppRule] {
        store.preferences.rules.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var selectedRule: AppRule? {
        guard case .rule(let id) = selection else { return nil }
        return store.preferences.rules.first { $0.id == id }
    }

    private var defaultDelaySummary: String {
        let delay = store.preferences.defaultDelay
        return delay == 0 ? "Instant" : "\(delay.formatted()) seconds"
    }

    private var canGoBack: Bool {
        backStack.contains { isValid($0) && $0 != selection }
    }

    private var canGoForward: Bool {
        forwardStack.contains { isValid($0) && $0 != selection }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 265)
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        ControlGroup {
                            Button(action: goBack) {
                                Label("Back", systemImage: "chevron.left")
                            }
                            .disabled(!canGoBack)
                            .help("Back")
                            .keyboardShortcut("[", modifiers: .command)

                            Button(action: goForward) {
                                Label("Forward", systemImage: "chevron.right")
                            }
                            .disabled(!canGoForward)
                            .help("Forward")
                            .keyboardShortcut("]", modifiers: .command)
                        }
                        .controlGroupStyle(.navigation)
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 460, idealHeight: 500)
        .onAppear {
            isSidebarFocused = true
        }
        .onChange(of: selection) { oldValue, newValue in
            if isNavigatingHistory {
                isNavigatingHistory = false
                return
            }
            guard let oldValue, oldValue != newValue, isValid(oldValue) else { return }
            if backStack.last != oldValue {
                backStack.append(oldValue)
            }
            forwardStack.removeAll()
        }
        .alert("Couldn’t Add Application", isPresented: Binding(
            get: { addError != nil },
            set: { if !$0 { addError = nil } }
        )) {
            Button("OK", role: .cancel) { addError = nil }
        } message: {
            Text(addError ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            generalSidebarRow
                .tag(SettingsSidebarItem.general)

            Section("App Rules") {
                if sortedRules.isEmpty {
                    Text("No app rules")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                        .selectionDisabled(true)
                } else {
                    ForEach(sortedRules) { rule in
                        appRuleSidebarRow(for: rule)
                            .tag(SettingsSidebarItem.rule(rule.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .focused($isSidebarFocused)
        .contentMargins(.top, 4, for: .scrollContent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarActionBar
        }
    }

    private var generalSidebarRow: some View {
        HStack(spacing: 8) {
            SettingsSidebarBadge(systemImage: "gear", color: Color(nsColor: .systemGray))
            VStack(alignment: .leading, spacing: 1) {
                Text("General")
                    .lineLimit(1)
                Text(service.isPaused ? "Paused" : "Active · \(defaultDelaySummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    private func appRuleSidebarRow(for rule: AppRule) -> some View {
        HStack(spacing: 8) {
            AppIcon(path: rule.path, bundleIdentifier: rule.bundleIdentifier, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name)
                    .lineLimit(1)
                Text(summary(for: rule))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }

    private var sidebarActionBar: some View {
        HStack {
            sidebarActionControls
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var sidebarActionControls: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    addRuleButton
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)

                    removeRuleButton
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                }
            }
        } else {
            HStack(spacing: 8) {
                addRuleButton
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)

                removeRuleButton
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
            }
        }
    }

    private var addRuleButton: some View {
        Button {
            addMenuController.present(
                runningApplications: runningApplications,
                onChooseApplication: chooseApplication,
                onAddURL: addApplication
            )
        } label: {
            Image(systemName: "plus")
                .frame(width: 16, height: 16)
        }
        .background(MenuAnchorView(controller: addMenuController).allowsHitTesting(false))
        .help("Add an app rule")
        .accessibilityLabel("Add an app rule")
    }

    private var removeRuleButton: some View {
        Button(action: removeSelectedRule) {
            Image(systemName: "minus")
                .frame(width: 16, height: 16)
        }
        .disabled(selectedRule == nil)
        .help("Remove rule; this app will use the default delay")
        .accessibilityLabel("Remove selected app rule")
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            generalDetails
        case .rule:
            if let rule = selectedRule {
                ruleDetails(for: rule)
            } else {
                emptySelectionView
            }
        case nil:
            emptySelectionView
        }
    }

    private var generalDetails: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    SettingsHeaderBadge(systemImage: "gear", color: Color(nsColor: .systemGray))
                    Text("General")
                        .font(.title2.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { !service.isPaused },
                    set: { service.isPaused = !$0 }
                )) {
                    SettingsRowLabel(
                        title: "Auto Hide",
                        systemImage: service.isPaused ? "eye" : "eye.slash"
                    )
                }
                .toggleStyle(.switch)
                .help(service.isPaused ? "Resume automatic hiding" : "Pause automatic hiding")

                LabeledContent {
                    DelayField(value: Binding(
                        get: { store.preferences.defaultDelay },
                        set: { store.preferences.defaultDelay = Preferences.validDelay($0) }
                    ))
                } label: {
                    SettingsRowLabel(title: "Default hide delay", systemImage: "timer")
                }
                .help("0 seconds hides immediately after switching away.")
            }
        }
        .formStyle(.grouped)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private func ruleDetails(for rule: AppRule) -> some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    AppIcon(path: rule.path, bundleIdentifier: rule.bundleIdentifier, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .help(rule.name)
                        Text(rule.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }

            Section {
                Toggle(isOn: ruleBinding(rule, \.neverHide)) {
                    SettingsRowLabel(title: "Never hide this app", systemImage: "eye")
                }
                .toggleStyle(.switch)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { rule.customDelay != nil },
                    set: { enabled in
                        store.updateRule(rule.id) {
                            $0.customDelay = enabled ? store.preferences.defaultDelay : nil
                        }
                    }
                )) {
                    SettingsRowLabel(title: "Use a custom delay", systemImage: "timer")
                }
                .toggleStyle(.switch)
                .disabled(rule.neverHide)
                .help("0 seconds hides immediately after switching away.")

                LabeledContent {
                    DelayField(value: Binding(
                        get: { rule.customDelay ?? store.preferences.defaultDelay },
                        set: { value in store.updateRule(rule.id) { $0.customDelay = value } }
                    ))
                } label: {
                    SettingsRowLabel(title: "Hide after", systemImage: "clock")
                }
                .disabled(rule.neverHide || rule.customDelay == nil)
                .help("0 seconds hides immediately after switching away.")
            }

            Section {
                Toggle(isOn: ruleBinding(rule, \.ignoreFocus)) {
                    SettingsRowLabel(
                        title: "Ignore when switching focus",
                        systemImage: "macwindow.and.cursorarrow"
                    )
                }
                .toggleStyle(.switch)
                .help("Switching to this app won’t start hiding the previous app. Existing countdowns continue.")
            }
        }
        .formStyle(.grouped)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private var emptySelectionView: some View {
        ContentUnavailableView(
            "No App Selected",
            systemImage: "macwindow.on.rectangle",
            description: Text("Select an app rule or click + to add one.")
        )
    }

    private var runningApplications: [NSRunningApplication] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.filter {
            guard $0.activationPolicy == .regular, let id = $0.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier, $0.bundleURL != nil,
                  !store.preferences.rules.contains(where: { $0.id == id }) else { return false }
            return seen.insert(id).inserted
        }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func ruleBinding(_ rule: AppRule, _ keyPath: WritableKeyPath<AppRule, Bool>) -> Binding<Bool> {
        Binding(
            get: { rule[keyPath: keyPath] },
            set: { value in store.updateRule(rule.id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func summary(for rule: AppRule) -> String {
        let delay = rule.customDelay ?? store.preferences.defaultDelay
        let timing = rule.neverHide ? "Never hide" : (delay == 0 ? "Instant" : "\(delay.formatted()) seconds")
        return rule.ignoreFocus ? "\(timing) · Focus ignored" : timing
    }

    private func goBack() {
        pruneHistory()
        while let target = backStack.popLast() {
            guard isValid(target), target != selection else { continue }
            if let current = selection, isValid(current), forwardStack.last != current {
                forwardStack.append(current)
            }
            isNavigatingHistory = true
            selection = target
            return
        }
    }

    private func goForward() {
        pruneHistory()
        while let target = forwardStack.popLast() {
            guard isValid(target), target != selection else { continue }
            if let current = selection, isValid(current), backStack.last != current {
                backStack.append(current)
            }
            isNavigatingHistory = true
            selection = target
            return
        }
    }

    private func isValid(_ item: SettingsSidebarItem) -> Bool {
        switch item {
        case .general:
            true
        case .rule(let id):
            store.preferences.rules.contains { $0.id == id }
        }
    }

    private func pruneHistory() {
        backStack = compactedHistory(backStack)
        forwardStack = compactedHistory(forwardStack)
        if backStack.last == selection { backStack.removeLast() }
        if forwardStack.last == selection { forwardStack.removeLast() }
    }

    private func compactedHistory(_ stack: [SettingsSidebarItem]) -> [SettingsSidebarItem] {
        var result: [SettingsSidebarItem] = []
        for item in stack where isValid(item) {
            if result.last != item {
                result.append(item)
            }
        }
        return result
    }

    private func removeSelectedRule() {
        guard case .rule(let id) = selection else { return }
        let currentRules = sortedRules
        let removedIndex = currentRules.firstIndex { $0.id == id }
        store.removeRule(id)
        let updatedRules = sortedRules
        let nextSelection: SettingsSidebarItem
        if let removedIndex, !updatedRules.isEmpty {
            let nextIndex = min(removedIndex, updatedRules.count - 1)
            nextSelection = .rule(updatedRules[nextIndex].id)
        } else {
            nextSelection = .general
        }
        isNavigatingHistory = true
        selection = nextSelection
        pruneHistory()
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Add an App Rule"
        panel.prompt = "Add App"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls { addApplication(url) }
        }
    }

    private func addApplication(_ url: URL) {
        if let id = store.addApplication(at: url) {
            selection = .rule(id)
        } else {
            addError = "Choose a macOS application with a bundle identifier. Auto Hide can’t add itself."
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct SettingsSidebarBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.gradient)
                .frame(width: 19, height: 19)
            Image(systemName: systemImage)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.white)
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}

private struct SettingsHeaderBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.gradient)
                .frame(width: 48, height: 48)
            Image(systemName: systemImage)
                .font(.system(size: 31, weight: .regular))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

private struct DelayField: View {
    @Binding var value: Double
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 6) {
            TextField("Seconds", value: $value, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .accessibilityLabel("Hide delay in seconds")
            Text("seconds")
                .foregroundStyle(.secondary)
                .opacity(isEnabled ? 1 : 0.45)
            Stepper("Hide delay", value: $value, in: 0...Preferences.maximumDelay, step: 1)
                .labelsHidden()
        }
        .fixedSize()
        .help("0 seconds hides immediately after switching away.")
    }
}

@MainActor
private final class AddRuleMenuController {
    weak var anchorView: NSView?
    private var actions: [MenuAction] = []

    func present(
        runningApplications: [NSRunningApplication],
        onChooseApplication: @escaping @MainActor () -> Void,
        onAddURL: @escaping @MainActor (URL) -> Void
    ) {
        guard let anchor = anchorView else { return }
        actions.removeAll()
        let menu = NSMenu()

        let chooseAction = MenuAction(onChooseApplication)
        actions.append(chooseAction)
        let chooseItem = NSMenuItem(
            title: "Choose Application…",
            action: #selector(MenuAction.invoke),
            keyEquivalent: ""
        )
        chooseItem.target = chooseAction
        chooseItem.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: nil)
        menu.addItem(chooseItem)

        if !runningApplications.isEmpty {
            menu.addItem(.separator())
            for app in runningApplications {
                guard let url = app.bundleURL else { continue }
                let action = MenuAction { onAddURL(url) }
                actions.append(action)
                let item = NSMenuItem(
                    title: app.localizedName ?? "Application",
                    action: #selector(MenuAction.invoke),
                    keyEquivalent: ""
                )
                item.target = action
                menu.addItem(item)
            }
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height + 4), in: anchor)
    }
}

private struct MenuAnchorView: NSViewRepresentable {
    let controller: AddRuleMenuController

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        controller.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        controller.anchorView = nsView
    }
}

@MainActor
private final class MenuAction: NSObject {
    private let handler: @MainActor () -> Void

    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @objc func invoke() {
        handler()
    }
}

private struct AppIcon: View {
    let path: String?
    let bundleIdentifier: String
    var size: CGFloat = 22

    private var resolvedPath: String? {
        if let path, FileManager.default.fileExists(atPath: path) {
            return path
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?.path
    }

    var body: some View {
        Group {
            if let resolvedPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: resolvedPath))
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: size * 0.65, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
