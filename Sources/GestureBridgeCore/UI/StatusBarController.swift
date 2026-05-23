import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let configStore: ConfigStore
    private let controller: GestureBridgeController
    private let frontmostAppProvider: FrontmostAppProvider
    private let settingsWindowController: SettingsWindowController

    init(
        configStore: ConfigStore,
        controller: GestureBridgeController,
        frontmostAppProvider: FrontmostAppProvider,
        settingsWindowController: SettingsWindowController
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.configStore = configStore
        self.controller = controller
        self.frontmostAppProvider = frontmostAppProvider
        self.settingsWindowController = settingsWindowController
        super.init()

        configureStatusItem()
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let currentBundleId = frontmostAppProvider.frontmostBundleId()
        let currentAppName = frontmostAppProvider.frontmostAppName() ?? "Unknown"
        let currentProfileName = configStore.profileName(for: currentBundleId)

        let enabledItem = NSMenuItem(
            title: configStore.current.enabled ? "GestureBridge: Enabled" : "GestureBridge: Disabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = configStore.current.enabled ? .on : .off
        menu.addItem(enabledItem)

        let overlayItem = NSMenuItem(
            title: "Show Gesture Overlay",
            action: #selector(toggleOverlay),
            keyEquivalent: ""
        )
        overlayItem.target = self
        overlayItem.state = configStore.current.showGestureOverlay ? .on : .off
        menu.addItem(overlayItem)

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = controller.launchAtLoginStatus == .enabled ? .on : .off
        launchItem.isEnabled = controller.launchAtLoginStatus != .unavailable
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(disabledItem(title: "Current app: \(currentAppName)"))
        menu.addItem(disabledItem(title: "Current profile: \(currentProfileName)"))

        if let currentBundleId {
            let disableItem = NSMenuItem(
                title: "Disable for \(currentAppName)",
                action: #selector(disableForCurrentApp),
                keyEquivalent: ""
            )
            disableItem.target = self
            disableItem.representedObject = currentBundleId
            menu.addItem(disableItem)
        }

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Open Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let permissionsItem = NSMenuItem(
            title: "Permissions...",
            action: #selector(openPermissions),
            keyEquivalent: ""
        )
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let gesturesItem = NSMenuItem(
            title: "Edit Gestures...",
            action: #selector(openGestures),
            keyEquivalent: ""
        )
        gesturesItem.target = self
        menu.addItem(gesturesItem)

        let diagnosticsItem = NSMenuItem(
            title: "Diagnostics...",
            action: #selector(openDiagnostics),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        let learnItem = NSMenuItem(
            title: "Learn Current App...",
            action: #selector(learnCurrentApp),
            keyEquivalent: ""
        )
        learnItem.target = self
        menu.addItem(learnItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = Self.menuBarIcon()
        button.imagePosition = .imageOnly
    }

    private static func menuBarIcon() -> NSImage? {
        let imageURL = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "svg")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets/MenuBarIconTemplate.svg")

        guard FileManager.default.fileExists(atPath: imageURL.path),
              let image = NSImage(contentsOf: imageURL)
        else {
            return NSImage(
                systemSymbolName: "arrow.triangle.2.circlepath",
                accessibilityDescription: "GestureBridge"
            )
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = "GestureBridge"
        return image
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleEnabled() {
        configStore.current.enabled.toggle()
        controller.refresh()
        rebuildMenu()
    }

    @objc private func toggleOverlay() {
        configStore.current.showGestureOverlay.toggle()
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        controller.setLaunchAtLogin(controller.launchAtLoginStatus != .enabled)
        rebuildMenu()
    }

    @objc private func openSettings() {
        controller.refresh()
        settingsWindowController.show(selecting: .general)
    }

    @objc private func openPermissions() {
        controller.refresh()
        settingsWindowController.show(selecting: .permissions)
    }

    @objc private func openGestures() {
        controller.refresh()
        settingsWindowController.show(selecting: .gestures)
    }

    @objc private func openDiagnostics() {
        controller.refresh()
        settingsWindowController.show(selecting: .diagnostics)
    }

    @objc private func learnCurrentApp() {
        if let bundleId = frontmostAppProvider.frontmostBundleId() {
            configStore.addCurrentApp(
                bundleId: bundleId,
                name: frontmostAppProvider.frontmostAppName()
            )
        }

        rebuildMenu()
    }

    @objc private func disableForCurrentApp(_ sender: NSMenuItem) {
        if let bundleId = sender.representedObject as? String {
            configStore.block(bundleId: bundleId)
            controller.refresh()
        }

        rebuildMenu()
    }
}
