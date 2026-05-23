import Combine
import Foundation

final class GestureBridgeController: ObservableObject {
    @Published private(set) var lastError: String?
    @Published private(set) var eventTapRunning: Bool = false
    @Published private(set) var permissions: PermissionSnapshot
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus

    private let configStore: ConfigStore
    private let permissionManager: PermissionManager
    private let eventTapManager: EventTapManager
    private let launchAtLoginManager: LaunchAtLoginManager

    init(
        configStore: ConfigStore,
        permissionManager: PermissionManager,
        eventTapManager: EventTapManager,
        launchAtLoginManager: LaunchAtLoginManager
    ) {
        self.configStore = configStore
        self.permissionManager = permissionManager
        self.eventTapManager = eventTapManager
        self.launchAtLoginManager = launchAtLoginManager
        self.permissions = permissionManager.snapshot()
        self.launchAtLoginStatus = launchAtLoginManager.status()
    }

    func refresh(promptForAccessibility: Bool = false) {
        permissions = permissionManager.snapshot(promptForAccessibility: promptForAccessibility)
        launchAtLoginStatus = launchAtLoginManager.status()

        guard configStore.current.enabled else {
            eventTapManager.stop()
            eventTapRunning = false
            lastError = nil
            return
        }

        guard permissions.canRunEventTap else {
            eventTapManager.stop()
            eventTapRunning = false
            lastError = "Accessibility and Input Monitoring permissions are required before gestures can run."
            return
        }

        do {
            try eventTapManager.start()
            eventTapRunning = eventTapManager.isRunning
            lastError = nil
        } catch {
            eventTapRunning = false
            lastError = error.localizedDescription
        }
    }

    func stop() {
        eventTapManager.stop()
        eventTapRunning = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(enabled)
            configStore.current.launchAtLogin = enabled
            launchAtLoginStatus = launchAtLoginManager.status()
            lastError = nil
        } catch {
            launchAtLoginStatus = .error
            lastError = error.localizedDescription
        }
    }
}
