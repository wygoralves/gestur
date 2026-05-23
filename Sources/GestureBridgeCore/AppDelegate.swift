import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configStore = ConfigStore()
    private let permissionManager = PermissionManager()
    private let frontmostAppProvider = FrontmostAppProvider()

    private var controller: GestureBridgeController?
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let profileMatcher = ProfileMatcher(configStore: configStore)
        let recognizer = GestureRecognizer(
            configStore: configStore,
            profileMatcher: profileMatcher
        )
        let actionDispatcher = ActionDispatcher()
        let overlayWindowController = OverlayWindowController()
        let eventTapManager = EventTapManager(
            recognizer: recognizer,
            frontmostAppProvider: frontmostAppProvider,
            actionDispatcher: actionDispatcher,
            configStore: configStore,
            overlayController: overlayWindowController
        )
        let controller = GestureBridgeController(
            configStore: configStore,
            permissionManager: permissionManager,
            eventTapManager: eventTapManager,
            launchAtLoginManager: LaunchAtLoginManager()
        )
        let settingsWindowController = SettingsWindowController(
            configStore: configStore,
            controller: controller,
            permissionManager: permissionManager,
            frontmostAppProvider: frontmostAppProvider
        )
        let statusBarController = StatusBarController(
            configStore: configStore,
            controller: controller,
            frontmostAppProvider: frontmostAppProvider,
            settingsWindowController: settingsWindowController
        )

        self.controller = controller
        self.settingsWindowController = settingsWindowController
        self.statusBarController = statusBarController

        configStore.onChange = { [weak controller, weak statusBarController] in
            controller?.refresh()
            statusBarController?.rebuildMenu()
        }

        controller.refresh()

        if !controller.permissions.canRunEventTap {
            settingsWindowController.show(selecting: .permissions)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
