import ApplicationServices
import CoreGraphics
import Foundation

enum EventTapError: LocalizedError {
    case couldNotCreateTap

    var errorDescription: String? {
        switch self {
        case .couldNotCreateTap:
            return "Gestur could not create the macOS event tap."
        }
    }
}

final class EventTapManager {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let recognizer: GestureRecognizer
    private let frontmostAppProvider: FrontmostAppProvider
    private let actionDispatcher: ActionDispatching
    private let configStore: ConfigStore
    private let overlayController: GestureOverlayControlling?
    private let diagnosticsStore: DiagnosticsStore

    init(
        recognizer: GestureRecognizer,
        frontmostAppProvider: FrontmostAppProvider,
        actionDispatcher: ActionDispatching,
        configStore: ConfigStore,
        overlayController: GestureOverlayControlling? = nil,
        diagnosticsStore: DiagnosticsStore
    ) {
        self.recognizer = recognizer
        self.frontmostAppProvider = frontmostAppProvider
        self.actionDispatcher = actionDispatcher
        self.configStore = configStore
        self.overlayController = overlayController
        self.diagnosticsStore = diagnosticsStore
    }

    var isRunning: Bool {
        tap != nil
    }

    func start() throws {
        guard tap == nil else { return }

        let mask = Self.eventMask(for: [
            .rightMouseDown,
            .rightMouseDragged,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseDragged,
            .otherMouseUp
        ])

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let createdTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: EventTapManager.eventTapCallback,
            userInfo: refcon
        ) else {
            throw EventTapError.couldNotCreateTap
        }

        tap = createdTap
        diagnosticsStore.updateEventTapState("Running")
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: createdTap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        tap = nil
        diagnosticsStore.updateEventTapState("Stopped")
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<EventTapManager>
            .fromOpaque(refcon)
            .takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }

            manager.diagnosticsStore.updateEventTapState("Re-enabled after \(type.diagnosticName)")
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == SyntheticEventMarker.value {
            return Unmanaged.passUnretained(event)
        }

        return manager.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let config = configStore.current

        guard config.enabled else {
            hideOverlay()
            if shouldCollectDiagnostics {
                updateDiagnostics(
                    type: type,
                    currentBundleId: frontmostAppProvider.frontmostBundleId(),
                    decision: "Pass-through: disabled",
                    snapshot: nil,
                    action: nil
                )
            }
            return Unmanaged.passUnretained(event)
        }

        guard config.trigger.button == .right else {
            hideOverlay()
            if shouldCollectDiagnostics {
                updateDiagnostics(
                    type: type,
                    currentBundleId: frontmostAppProvider.frontmostBundleId(),
                    decision: "Pass-through: unsupported trigger",
                    snapshot: nil,
                    action: nil
                )
            }
            return Unmanaged.passUnretained(event)
        }

        let currentBundleId = frontmostAppProvider.frontmostBundleId()
        let isGestureContinuation = recognizer.hasActiveSession &&
            (type == .rightMouseDragged || type == .rightMouseUp)

        let bundleId: String

        if isGestureContinuation, let activeBundleId = recognizer.activeBundleId {
            bundleId = activeBundleId
        } else {
            guard let unwrappedBundleId = currentBundleId,
                  config.isEnabledForBundleId(unwrappedBundleId)
            else {
                hideOverlay()
                if shouldCollectDiagnostics {
                    updateDiagnostics(
                        type: type,
                        currentBundleId: currentBundleId,
                        decision: "Pass-through: no enabled profile",
                        snapshot: nil,
                        action: nil
                    )
                }
                return Unmanaged.passUnretained(event)
            }

            bundleId = unwrappedBundleId
        }

        let previousSnapshot = recognizer.activeSnapshot
        let decision = recognizer.handle(type: type, event: event, bundleId: bundleId)
        let currentSnapshot = recognizer.activeSnapshot ?? previousSnapshot
        updateOverlayIfNeeded(type: type, config: config)
        if shouldCollectDiagnostics {
            updateDiagnostics(
                type: type,
                currentBundleId: bundleId,
                decision: decision.diagnosticName,
                snapshot: currentSnapshot,
                action: decision.action
            )
        }

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .dispatch(let action):
            DispatchQueue.main.async { [actionDispatcher] in
                actionDispatcher.dispatch(action)
            }
            return nil
        case .replayRightClick(let originalDown, let up):
            DispatchQueue.main.async { [weak self] in
                self?.replayRightClick(originalDown: originalDown, up: up)
            }
            return nil
        }
    }

    private func replayRightClick(originalDown: CGEvent, up: CGEvent) {
        originalDown.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.value)
        up.setIntegerValueField(.eventSourceUserData, value: SyntheticEventMarker.value)

        originalDown.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func updateOverlayIfNeeded(type: CGEventType, config: AppConfig) {
        guard config.showGestureOverlay else {
            if type == .rightMouseUp {
                hideOverlay()
            }
            return
        }

        switch type {
        case .rightMouseDown, .rightMouseDragged:
            guard let snapshot = recognizer.activeSnapshot else {
                return
            }

            DispatchQueue.main.async { [overlayController] in
                overlayController?.show(snapshot: snapshot)
            }
        case .rightMouseUp:
            DispatchQueue.main.async { [overlayController] in
                overlayController?.hide(after: 0.45)
            }
        default:
            break
        }
    }

    private func hideOverlay() {
        DispatchQueue.main.async { [overlayController] in
            overlayController?.hideImmediately()
        }
    }

    private func updateDiagnostics(
        type: CGEventType,
        currentBundleId: String?,
        decision: String,
        snapshot: GestureOverlaySnapshot?,
        action: GestureAction?
    ) {
        let profileName = currentBundleId.flatMap { configStore.current.profile(for: $0)?.name }

        diagnosticsStore.updateCurrentApp(
            bundleId: currentBundleId,
            appName: frontmostAppProvider.frontmostAppName(),
            profileName: profileName
        )
        diagnosticsStore.updateEvent(
            type: type.diagnosticName,
            decision: decision,
            gestureToken: snapshot?.token,
            actionLabel: snapshot?.actionLabel,
            actionDescription: action?.displayText
        )
    }

    private var shouldCollectDiagnostics: Bool {
        diagnosticsStore.shouldCollectEventDetails
    }

    private static func eventMask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }
    }
}

private extension CGEventType {
    var diagnosticName: String {
        switch self {
        case .rightMouseDown:
            return "Right mouse down"
        case .rightMouseDragged:
            return "Right mouse dragged"
        case .rightMouseUp:
            return "Right mouse up"
        case .tapDisabledByTimeout:
            return "Tap disabled by timeout"
        case .tapDisabledByUserInput:
            return "Tap disabled by user input"
        default:
            return "Event \(rawValue)"
        }
    }
}

private extension GestureDecision {
    var diagnosticName: String {
        switch self {
        case .passThrough:
            return "Pass-through"
        case .swallow:
            return "Swallow"
        case .dispatch:
            return "Dispatch action"
        case .replayRightClick:
            return "Replay right-click"
        }
    }

    var action: GestureAction? {
        if case .dispatch(let action) = self {
            return action
        }

        return nil
    }
}
