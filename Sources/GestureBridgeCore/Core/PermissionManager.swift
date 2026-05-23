import AppKit
import ApplicationServices
import IOKit.hid

enum PermissionStatus: String {
    case granted
    case missing
    case unknown
}

struct PermissionSnapshot: Equatable {
    var accessibility: PermissionStatus
    var inputMonitoring: PermissionStatus

    var canRunEventTap: Bool {
        accessibility == .granted && inputMonitoring == .granted
    }
}

final class PermissionManager {
    func snapshot(promptForAccessibility: Bool = false) -> PermissionSnapshot {
        PermissionSnapshot(
            accessibility: isAccessibilityTrusted(prompt: promptForAccessibility) ? .granted : .missing,
            inputMonitoring: inputMonitoringStatus()
        )
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func inputMonitoringStatus() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .missing
        case kIOHIDAccessTypeUnknown:
            return .unknown
        default:
            return .unknown
        }
    }

    func openAccessibilitySettings() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openPrivacyPane(anchor: "Privacy_ListenEvent")
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
