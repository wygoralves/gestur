import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    private let configStore: ConfigStore
    private let controller: GestureBridgeController
    private let permissionManager: PermissionManager
    private let frontmostAppProvider: FrontmostAppProvider

    init(
        configStore: ConfigStore,
        controller: GestureBridgeController,
        permissionManager: PermissionManager,
        frontmostAppProvider: FrontmostAppProvider
    ) {
        self.configStore = configStore
        self.controller = controller
        self.permissionManager = permissionManager
        self.frontmostAppProvider = frontmostAppProvider
    }

    func show(selecting tab: SettingsTab = .general) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Gestur Settings"
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }

        window?.contentView = NSHostingView(rootView: makeView(selecting: tab))
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeView(selecting tab: SettingsTab) -> SettingsView {
        SettingsView(
            selectedTab: tab,
            configStore: configStore,
            controller: controller,
            permissionManager: permissionManager,
            frontmostAppProvider: frontmostAppProvider
        )
    }
}
