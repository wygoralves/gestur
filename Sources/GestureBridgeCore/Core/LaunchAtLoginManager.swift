import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: String, Equatable {
    case available
    case enabled
    case requiresApproval
    case unavailable
    case error

    var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Needs approval"
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        }
    }
}

final class LaunchAtLoginManager {
    var isAvailable: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    func status() -> LaunchAtLoginStatus {
        guard isAvailable else {
            return .unavailable
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .available
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else {
            throw LaunchAtLoginError.requiresAppBundle
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case requiresAppBundle

    var errorDescription: String? {
        switch self {
        case .requiresAppBundle:
            return "Launch at login requires running GestureBridge from a bundled .app."
        }
    }
}
