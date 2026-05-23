import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case gestures = "Gestures"
    case profiles = "Profiles"
    case permissions = "Permissions"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .gestures:
            return "point.3.connected.trianglepath.dotted"
        case .profiles:
            return "globe"
        case .permissions:
            return "lock.shield"
        }
    }
}

struct SettingsView: View {
    @State var selectedTab: SettingsTab
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var controller: GestureBridgeController

    let permissionManager: PermissionManager
    let frontmostAppProvider: FrontmostAppProvider

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selectedTab: $selectedTab)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView(
                            configStore: configStore,
                            controller: controller
                        )
                    case .gestures:
                        GestureRulesView(configStore: configStore)
                    case .profiles:
                        ProfilesView(
                            configStore: configStore,
                            frontmostAppProvider: frontmostAppProvider
                        )
                    case .permissions:
                        PermissionView(
                            controller: controller,
                            permissionManager: permissionManager
                        )
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 860, minHeight: 600)
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("GestureBridge")
                    .font(.system(size: 18, weight: .semibold))
                Text("Browser mouse gestures")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)

            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SidebarButtonStyle(isSelected: selectedTab == tab))
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 196)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.14) : .clear)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var controller: GestureBridgeController

    var body: some View {
        SettingsPage(
            title: "General",
            subtitle: "Control when gestures run and how quickly movement becomes a command."
        ) {
            SettingsSection(title: "Runtime") {
                ToggleRow(
                    title: "Enable GestureBridge",
                    subtitle: "Turn global browser gestures on or off.",
                    isOn: $configStore.current.enabled
                )

                Divider()

                ToggleRow(
                    title: "Show gesture overlay",
                    subtitle: "Display a small debug HUD with the recognized token and action.",
                    isOn: $configStore.current.showGestureOverlay
                )

                Divider()

                LaunchAtLoginRow(
                    controller: controller,
                    isConfigured: $configStore.current.launchAtLogin
                )

                Divider()

                StatusRow(
                    title: "Event tap",
                    subtitle: controller.eventTapRunning ? "Listening for right-button gestures." : "Stopped until enabled and permissions are available.",
                    status: controller.eventTapRunning ? "Running" : "Stopped",
                    tone: controller.eventTapRunning ? .success : .neutral
                )

                if let lastError = controller.lastError {
                    Text(lastError)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }

            SettingsSection(title: "Gesture recognition") {
                DisabledPickerRow(
                    title: "Trigger",
                    value: MouseButton.right.displayName,
                    subtitle: "Right-button drag is the active MVP trigger."
                )

                Divider()

                ToggleRow(
                    title: "Browser-only mode",
                    subtitle: "GestureBridge only acts in enabled browser profiles.",
                    isOn: $configStore.current.browserOnlyMode
                )
                .disabled(true)

                Divider()

                ThresholdSlider(
                    title: "Minimum movement",
                    subtitle: "Distance before a right-click becomes a gesture.",
                    value: $configStore.current.recognition.minimumMovementPx,
                    range: 8...80,
                    suffix: "px"
                )

                Divider()

                ThresholdSlider(
                    title: "Segment threshold",
                    subtitle: "Distance between direction samples.",
                    value: $configStore.current.recognition.segmentThresholdPx,
                    range: 4...48,
                    suffix: "px"
                )

                Divider()

                ThresholdSlider(
                    title: "Jitter tolerance",
                    subtitle: "Small movement ignored while classifying directions.",
                    value: $configStore.current.recognition.jitterTolerancePx,
                    range: 0...24,
                    suffix: "px"
                )
            }

            HStack {
                Button("Recheck status") {
                    controller.refresh()
                }

                Button("Restore defaults") {
                    configStore.resetToDefaults()
                    controller.refresh()
                }
            }
        }
    }
}

private struct LaunchAtLoginRow: View {
    @ObservedObject var controller: GestureBridgeController
    @Binding var isConfigured: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Launch at login")
                    .font(.system(size: 13, weight: .medium))
                Text(controller.launchAtLoginStatus == .unavailable ? "Build and run the .app bundle before enabling this." : "Start GestureBridge automatically after signing in.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusPill(
                text: controller.launchAtLoginStatus.displayText,
                tone: controller.launchAtLoginStatus == .enabled ? .success : .neutral
            )

            Toggle(
                "",
                isOn: Binding(
                    get: { controller.launchAtLoginStatus == .enabled || isConfigured },
                    set: { controller.setLaunchAtLogin($0) }
                )
            )
            .labelsHidden()
            .disabled(controller.launchAtLoginStatus == .unavailable)
        }
    }
}

private struct DisabledPickerRow: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ThresholdSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let suffix: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
                .frame(width: 230, alignment: .leading)

            Slider(value: $value, in: range)

            Text("\(Int(value)) \(suffix)")
                .font(.system(size: 13, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

struct PermissionView: View {
    @ObservedObject var controller: GestureBridgeController
    let permissionManager: PermissionManager

    var body: some View {
        SettingsPage(
            title: "Permissions",
            subtitle: "macOS requires explicit approval before GestureBridge can observe gestures or send shortcuts."
        ) {
            SettingsSection(title: "Required access") {
                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Allows GestureBridge to send browser keyboard shortcuts.",
                    status: controller.permissions.accessibility,
                    actionTitle: "Open Accessibility",
                    action: permissionManager.openAccessibilitySettings
                )

                Divider()

                PermissionRow(
                    title: "Input Monitoring",
                    subtitle: "Allows GestureBridge to observe mouse movement while another app is frontmost.",
                    status: controller.permissions.inputMonitoring,
                    actionTitle: "Open Input Monitoring",
                    action: permissionManager.openInputMonitoringSettings
                )
            }

            HStack {
                Button("Prompt Accessibility") {
                    controller.refresh(promptForAccessibility: true)
                }

                Button("Recheck permissions") {
                    controller.refresh()
                }
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let status: PermissionStatus
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)

            Spacer()

            StatusPill(
                text: status.rawValue.capitalized,
                tone: status == .granted ? .success : .warning
            )

            Button(actionTitle, action: action)
        }
    }
}

private struct ProfilesView: View {
    @ObservedObject var configStore: ConfigStore
    let frontmostAppProvider: FrontmostAppProvider

    var body: some View {
        SettingsPage(
            title: "Profiles",
            subtitle: "Choose which browser bundle IDs receive gestures."
        ) {
            SettingsSection(title: "Browser profiles") {
                ForEach($configStore.current.profiles) { $profile in
                    ProfileEditor(profile: $profile)

                    if profile.id != configStore.current.profiles.last?.id {
                        Divider()
                    }
                }
            }

            HStack {
                Button {
                    if let bundleId = frontmostAppProvider.frontmostBundleId() {
                        configStore.addCurrentApp(
                            bundleId: bundleId,
                            name: frontmostAppProvider.frontmostAppName()
                        )
                    }
                } label: {
                    Label("Learn current app", systemImage: "plus")
                }

                Button {
                    if let bundleId = frontmostAppProvider.frontmostBundleId() {
                        configStore.block(bundleId: bundleId)
                    }
                } label: {
                    Label("Disable current app", systemImage: "minus.circle")
                }
            }
        }
    }
}

private struct ProfileEditor: View {
    @Binding var profile: BrowserProfile
    @State private var newBundleId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Toggle("", isOn: $profile.enabled)
                    .labelsHidden()

                TextField("Profile name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(profile.bundleIds, id: \.self) { bundleId in
                    HStack {
                        Text(bundleId)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            profile.bundleIds.removeAll { $0 == bundleId }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove bundle ID")
                    }
                }

                HStack {
                    TextField("com.example.Browser", text: $newBundleId)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        let trimmed = newBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !profile.bundleIds.contains(trimmed) else {
                            return
                        }

                        profile.bundleIds.append(trimmed)
                        newBundleId = ""
                    }
                    .disabled(newBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.leading, 28)
        }
    }
}

private struct GestureRulesView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var selectedProfileId: UUID?

    var body: some View {
        SettingsPage(
            title: "Gestures",
            subtitle: "Edit the gesture token and shortcut sent for each browser profile."
        ) {
            SettingsSection(title: "Profile") {
                HStack {
                    Picker("Profile", selection: selectedProfileBinding) {
                        ForEach(configStore.current.profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 260)

                    Spacer()

                    Button {
                        addRule()
                    } label: {
                        Label("Add rule", systemImage: "plus")
                    }
                }
            }

            if let profile = selectedProfile {
                SettingsSection(title: "\(profile.wrappedValue.name) rules") {
                    VStack(spacing: 0) {
                        RuleHeader()

                        Divider()

                        ForEach(profile.wrappedValue.rules.indices, id: \.self) { index in
                            RuleEditorRow(
                                rule: profile.rules[index],
                                onDelete: {
                                    profile.wrappedValue.rules.remove(at: index)
                                }
                            )

                            if index != profile.wrappedValue.rules.indices.last {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedProfileId = selectedProfileId ?? configStore.current.profiles.first?.id
        }
    }

    private var selectedProfileBinding: Binding<UUID?> {
        Binding(
            get: {
                selectedProfileId ?? configStore.current.profiles.first?.id
            },
            set: { selectedProfileId = $0 }
        )
    }

    private var selectedProfile: Binding<BrowserProfile>? {
        let id = selectedProfileId ?? configStore.current.profiles.first?.id

        guard let id,
              let index = configStore.current.profiles.firstIndex(where: { $0.id == id })
        else {
            return nil
        }

        return $configStore.current.profiles[index]
    }

    private func addRule() {
        guard let profile = selectedProfile else {
            return
        }

        profile.wrappedValue.rules.append(
            GestureRule(
                id: UUID(),
                gesture: "",
                label: "New rule",
                action: .shortcut(ShortcutAction(key: .t, modifiers: [.command]))
            )
        )
    }
}

private struct RuleHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Gesture")
                .frame(width: 76, alignment: .leading)
            Text("Label")
                .frame(minWidth: 150, alignment: .leading)
            Text("Key")
                .frame(width: 120, alignment: .leading)
            Text("Modifiers")
                .frame(width: 190, alignment: .leading)
            Spacer()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.vertical, 7)
    }
}

private struct RuleEditorRow: View {
    @Binding var rule: GestureRule
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("D", text: $rule.gesture)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 76)

            TextField("Action label", text: $rule.label)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 150)

            ShortcutEditor(action: $rule.action)

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete rule")
        }
        .padding(.vertical, 8)
    }
}

private struct ShortcutEditor: View {
    @Binding var action: GestureAction

    var body: some View {
        let shortcut = Binding<ShortcutAction>(
            get: {
                if case .shortcut(let shortcut) = action {
                    return shortcut
                }

                return ShortcutAction(key: .t, modifiers: [.command])
            },
            set: { action = .shortcut($0) }
        )

        HStack(spacing: 12) {
            Picker("Key", selection: shortcut.key) {
                ForEach(KeyCodeToken.allCases) { token in
                    Text(token.displayName).tag(token)
                }
            }
            .labelsHidden()
            .frame(width: 120)

            HStack(spacing: 5) {
                ForEach(ModifierKey.displayOrder) { modifier in
                    Toggle(
                        modifier.symbol,
                        isOn: Binding(
                            get: { shortcut.wrappedValue.modifiers.contains(modifier) },
                            set: { enabled in
                                var updated = shortcut.wrappedValue

                                if enabled {
                                    if !updated.modifiers.contains(modifier) {
                                        updated.modifiers.append(modifier)
                                    }
                                } else {
                                    updated.modifiers.removeAll { $0 == modifier }
                                }

                                shortcut.wrappedValue = updated
                            }
                        )
                    )
                    .toggleStyle(.button)
                    .help(modifier.rawValue.capitalized)
                }
            }
            .frame(width: 190, alignment: .leading)
        }
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            content
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct StatusRow: View {
    let title: String
    let subtitle: String
    let status: String
    let tone: StatusTone

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer()
            StatusPill(text: status, tone: tone)
        }
    }
}

private struct RowText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum StatusTone {
    case success
    case warning
    case neutral
}

private struct StatusPill: View {
    let text: String
    let tone: StatusTone

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch tone {
        case .success:
            return .green
        case .warning:
            return .orange
        case .neutral:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .success:
            return .green.opacity(0.12)
        case .warning:
            return .orange.opacity(0.13)
        case .neutral:
            return Color(nsColor: .controlBackgroundColor)
        }
    }
}

private extension Binding where Value == ShortcutAction {
    var key: Binding<KeyCodeToken> {
        Binding<KeyCodeToken>(
            get: { wrappedValue.key },
            set: { wrappedValue.key = $0 }
        )
    }
}
