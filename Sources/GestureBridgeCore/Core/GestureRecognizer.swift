import CoreGraphics
import Foundation

final class GestureRecognizer {
    private var session: GestureSession?

    private let configStore: ConfigStore
    private let profileMatcher: ProfileMatcher
    private let now: () -> Date

    init(
        configStore: ConfigStore,
        profileMatcher: ProfileMatcher,
        now: @escaping () -> Date = Date.init
    ) {
        self.configStore = configStore
        self.profileMatcher = profileMatcher
        self.now = now
    }

    var hasActiveSession: Bool {
        session != nil
    }

    var activeBundleId: String? {
        session?.bundleId
    }

    var activeSnapshot: GestureOverlaySnapshot? {
        guard let session else {
            return nil
        }

        let actionLabel = profileMatcher.match(
            bundleId: session.bundleId,
            gesture: session.token
        )?.label

        return GestureOverlaySnapshot(
            points: session.points,
            token: session.token,
            actionLabel: actionLabel,
            didExceedThreshold: session.didExceedThreshold
        )
    }

    func handle(phase: GesturePhase, event: CGEvent, bundleId: String) -> GestureDecision {
        switch phase {
        case .down:
            return handleMouseDown(event: event, bundleId: bundleId)
        case .dragged:
            return handleMouseDragged(event: event)
        case .up:
            return handleMouseUp(event: event)
        }
    }

    private func handleMouseDown(event: CGEvent, bundleId: String) -> GestureDecision {
        guard let originalDownEvent = event.copy() else {
            return .passThrough
        }

        let point = event.location

        session = GestureSession(
            bundleId: bundleId,
            startPoint: point,
            lastPoint: point,
            startedAt: now(),
            originalDownEvent: originalDownEvent,
            points: [point],
            directions: [],
            didExceedThreshold: false
        )

        return .swallow
    }

    private func handleMouseDragged(event: CGEvent) -> GestureDecision {
        guard var current = session else {
            return .passThrough
        }

        let config = configStore.current.recognition
        let point = event.location
        current.points.append(point)

        let elapsedMs = now().timeIntervalSince(current.startedAt) * 1000
        if elapsedMs > Double(config.maxGestureDurationMs) {
            session = current
            return .swallow
        }

        let dx = point.x - current.lastPoint.x
        let dy = point.y - current.lastPoint.y
        let distance = hypot(dx, dy)

        if distance >= config.segmentThresholdPx,
           let direction = Direction.classify(
                dx: dx,
                dy: dy,
                jitterTolerance: config.jitterTolerancePx
           ) {
            if current.directions.last != direction {
                current.directions.append(direction)
            }

            current.lastPoint = point
        }

        let totalDistance = hypot(
            point.x - current.startPoint.x,
            point.y - current.startPoint.y
        )

        if totalDistance >= config.minimumMovementPx {
            current.didExceedThreshold = true
        }

        session = current
        return .swallow
    }

    private func handleMouseUp(event: CGEvent) -> GestureDecision {
        guard let current = session else {
            return .passThrough
        }

        defer { session = nil }

        guard current.didExceedThreshold else {
            guard let originalDown = current.originalDownEvent.copy(),
                  let up = event.copy()
            else {
                return .passThrough
            }

            return .replayClick(originalDown: originalDown, up: up)
        }

        guard let rule = profileMatcher.match(
            bundleId: current.bundleId,
            gesture: current.token
        ) else {
            return .swallow
        }

        return .dispatch(rule.action)
    }
}
