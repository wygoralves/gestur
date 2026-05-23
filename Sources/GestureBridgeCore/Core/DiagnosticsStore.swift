import Combine
import Foundation

struct DiagnosticsSnapshot: Equatable {
    var currentBundleId: String?
    var currentAppName: String?
    var currentProfileName: String?
    var eventTapState: String
    var lastEventType: String?
    var lastDecision: String?
    var lastGestureToken: String?
    var lastActionLabel: String?
    var lastActionDescription: String?
    var lastUpdatedAt: Date?

    static let empty = DiagnosticsSnapshot(
        currentBundleId: nil,
        currentAppName: nil,
        currentProfileName: nil,
        eventTapState: "Stopped",
        lastEventType: nil,
        lastDecision: nil,
        lastGestureToken: nil,
        lastActionLabel: nil,
        lastActionDescription: nil,
        lastUpdatedAt: nil
    )
}

final class DiagnosticsStore: ObservableObject {
    @Published private(set) var snapshot = DiagnosticsSnapshot.empty
    private var isCollectingEventDetails = false

    var shouldCollectEventDetails: Bool {
        isCollectingEventDetails
    }

    func setCollectingEventDetails(_ isCollecting: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isCollectingEventDetails = isCollecting
        }
    }

    func updateEventTapState(_ state: String) {
        mutate { snapshot in
            snapshot.eventTapState = state
        }
    }

    func updatePermissions(
        _ permissions: PermissionSnapshot,
        launchAtLoginStatus: LaunchAtLoginStatus
    ) {
        mutate { snapshot in
            snapshot.lastUpdatedAt = Date()
            snapshot.lastDecision = "Permissions: Accessibility \(permissions.accessibility.rawValue), Input Monitoring \(permissions.inputMonitoring.rawValue), Login \(launchAtLoginStatus.displayText)"
        }
    }

    func updateCurrentApp(
        bundleId: String?,
        appName: String?,
        profileName: String?
    ) {
        mutate { snapshot in
            snapshot.currentBundleId = bundleId
            snapshot.currentAppName = appName
            snapshot.currentProfileName = profileName
        }
    }

    func updateEvent(
        type: String,
        decision: String,
        gestureToken: String?,
        actionLabel: String?,
        actionDescription: String?
    ) {
        mutate { snapshot in
            snapshot.lastEventType = type
            snapshot.lastDecision = decision
            snapshot.lastGestureToken = gestureToken
            snapshot.lastActionLabel = actionLabel
            snapshot.lastActionDescription = actionDescription
        }
    }

    private func mutate(_ update: @escaping (inout DiagnosticsSnapshot) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            var updated = snapshot
            update(&updated)
            updated.lastUpdatedAt = Date()
            snapshot = updated
        }
    }
}
