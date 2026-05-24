import CoreGraphics
import Foundation
@testable import GestureBridgeCore

@main
enum GestureBridgeValidation {
    private static var failures: [String] = []

    static func main() {
        validateGestureRecognition()
        validateTriggerMatching()
        validateProfileMatching()
        validateShortcutMapping()
        validateConfigMigration()
        validateConfigImportExport()

        if failures.isEmpty {
            print("Gestur validation passed.")
        } else {
            for failure in failures {
                fputs("Validation failure: \(failure)\n", stderr)
            }
            exit(1)
        }
    }

    private static func validateGestureRecognition() {
        let config = RecognitionConfig(
            minimumMovementPx: 22,
            segmentThresholdPx: 12,
            jitterTolerancePx: 6,
            maxGestureDurationMs: 1200
        )

        expect(token([(0, 0), (-30, 0)], config) == "L", "Simple left movement")
        expect(token([(0, 0), (30, 0)], config) == "R", "Simple right movement")
        expect(token([(0, 0), (0, -30)], config) == "U", "Simple up movement")
        expect(token([(0, 0), (0, 30)], config) == "D", "Simple down movement")
        expect(token([(0, 0), (0, 30), (30, 30)], config) == "DR", "Down then right")
        expect(token([(0, 0), (0, 30), (0, -8)], config) == "DU", "Down then up")
        expect(token([(0, 0), (0, -30), (-30, -30)], config) == "UL", "Up then left")
        expect(token([(0, 0), (0, -30), (30, -30)], config) == "UR", "Up then right")
        expect(token([(0, 0), (0, -30), (0, 10)], config) == "UD", "Up then down")
        expect(token([(0, 0), (5, 0), (10, 0)], config).isEmpty, "Jitter below threshold")
        expect(token([(0, 0), (30, 0), (60, 0)], config) == "R", "Repeated direction collapse")
    }

    private static func validateTriggerMatching() {
        let rightTrigger = TriggerConfig(button: .right, requiredModifiers: [])
        expect(
            rightTrigger.gesturePhase(for: .rightMouseDown, event: mouseEvent(type: .rightMouseDown, button: .right)) == .down,
            "Right trigger matches right down"
        )
        expect(
            rightTrigger.gesturePhase(for: .rightMouseDragged, event: mouseEvent(type: .rightMouseDragged, button: .right)) == .dragged,
            "Right trigger matches right drag"
        )
        expect(
            rightTrigger.gesturePhase(for: .rightMouseUp, event: mouseEvent(type: .rightMouseUp, button: .right)) == .up,
            "Right trigger matches right up"
        )
        expect(
            rightTrigger.gesturePhase(for: .otherMouseDown, event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 2)) == nil,
            "Right trigger ignores middle down"
        )

        let middleTrigger = TriggerConfig(button: .middle, requiredModifiers: [])
        expect(
            middleTrigger.gesturePhase(for: .otherMouseDown, event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 2)) == .down,
            "Middle trigger matches middle down"
        )
        expect(
            middleTrigger.gesturePhase(for: .otherMouseDragged, event: otherMouseEvent(type: .otherMouseDragged, buttonNumber: 2)) == .dragged,
            "Middle trigger matches middle drag"
        )
        expect(
            middleTrigger.gesturePhase(for: .otherMouseUp, event: otherMouseEvent(type: .otherMouseUp, buttonNumber: 2)) == .up,
            "Middle trigger matches middle up"
        )
        expect(
            middleTrigger.gesturePhase(for: .otherMouseDown, event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 4)) == nil,
            "Middle trigger ignores side button"
        )

        let sideTrigger = TriggerConfig(button: .other, requiredModifiers: [], otherButtonNumber: 4)
        expect(
            sideTrigger.gesturePhase(for: .otherMouseDown, event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 4)) == .down,
            "Other trigger matches configured button"
        )
        expect(
            sideTrigger.gesturePhase(for: .otherMouseDown, event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 3)) == nil,
            "Other trigger ignores different button"
        )

        let modifiedTrigger = TriggerConfig(button: .other, requiredModifiers: [.option], otherButtonNumber: 4)
        expect(
            modifiedTrigger.gesturePhase(for: .otherMouseDown, event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 4)) == nil,
            "Required modifier blocks trigger start"
        )
        expect(
            modifiedTrigger.gesturePhase(
                for: .otherMouseDown,
                event: otherMouseEvent(type: .otherMouseDown, buttonNumber: 4, modifiers: [.option])
            ) == .down,
            "Required modifier allows trigger start"
        )
        expect(
            modifiedTrigger.gesturePhase(
                for: .otherMouseDragged,
                event: otherMouseEvent(type: .otherMouseDragged, buttonNumber: 4),
                requireModifiers: false
            ) == .dragged,
            "Active trigger continuation does not require modifiers"
        )
    }

    private static func validateProfileMatching() {
        let store = ConfigStore(fileURL: temporaryConfigURL())
        let matcher = ProfileMatcher(configStore: store)

        expect(matcher.profile(for: "com.google.Chrome")?.name == "Chromium browsers", "Chrome profile")
        expect(matcher.profile(for: "company.thebrowser.dia")?.name == "Dia", "Dia profile")
        expect(matcher.profile(for: "company.thebrowser.Browser") == nil, "Arc is not enabled by default")
        expect(matcher.profile(for: "com.vivaldi.Vivaldi")?.name == "Vivaldi", "Vivaldi profile")
        expect(matcher.profile(for: "com.apple.Safari")?.name == "Safari", "Safari profile")
        expect(matcher.profile(for: "org.mozilla.firefox")?.name == "Firefox", "Firefox profile")
        expect(matcher.match(bundleId: "com.example.Unknown", gesture: "D") == nil, "Unknown app pass-through")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "D")?.label == "Close tab", "Down closes tab")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "U")?.label == "New tab", "Up opens new tab")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "R")?.label == "Next tab", "Right moves to right tab")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "L")?.label == "Previous tab", "Left moves to left tab")
        expect(matcher.match(bundleId: "company.thebrowser.dia", gesture: "R")?.action == .diaTab(.next), "Dia right uses next tab menu action")
        expect(matcher.match(bundleId: "company.thebrowser.dia", gesture: "L")?.action == .diaTab(.previous), "Dia left uses previous tab menu action")
        expect(matcher.match(bundleId: "com.vivaldi.Vivaldi", gesture: "R")?.action == .vivaldiTab(.nextByOrder), "Vivaldi right uses scripted tab-order action")
        expect(matcher.match(bundleId: "com.vivaldi.Vivaldi", gesture: "L")?.action == .vivaldiTab(.previousByOrder), "Vivaldi left uses scripted tab-order action")

        store.block(bundleId: "com.google.Chrome")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "D") == nil, "Blocked app pass-through")
    }

    private static func validateShortcutMapping() {
        expect(KeyCodeMapper.keyCode(for: .t) == 17, "T key mapping")
        expect(KeyCodeMapper.keyCode(for: .w) == 13, "W key mapping")
        expect(KeyCodeMapper.keyCode(for: .one) == 18, "1 key mapping")
        expect(KeyCodeMapper.keyCode(for: .two) == 19, "2 key mapping")
        expect(KeyCodeMapper.keyCode(for: .rightArrow) == 124, "Right arrow mapping")
        expect(KeyCodeMapper.keyCode(for: .leftBracket) == 33, "Left bracket mapping")
        expect(KeyCodeMapper.keyCode(for: .rightBracket) == 30, "Right bracket mapping")
        expect(KeyCodeMapper.keyCode(for: .tab) == 48, "Tab mapping")

        let command = CGEventFlags.from([.command])
        expect(command.contains(.maskCommand), "Command flag")
        expect(!command.contains(.maskShift), "Command flag excludes shift")

        let commandOption = CGEventFlags.from([.command, .option])
        expect(commandOption.contains(.maskCommand), "Command-option includes command")
        expect(commandOption.contains(.maskAlternate), "Command-option includes option")

        let controlShift = CGEventFlags.from([.control, .shift])
        expect(controlShift.contains(.maskControl), "Control-shift includes control")
        expect(controlShift.contains(.maskShift), "Control-shift includes shift")

        for key in KeyCodeToken.allCases {
            expect(KeyCodeMapper.keyCode(for: key) != nil, "Key token \(key.rawValue) has mapping")
        }
    }

    private static func validateConfigMigration() {
        let url = temporaryConfigURL()
        let store = ConfigStore(fileURL: url)
        var oldConfig = store.current

        oldConfig.defaultsRevision = 2
        oldConfig.profiles.removeAll { $0.id == DefaultProfiles.vivaldiProfileId }
        if let chromiumIndex = oldConfig.profiles.firstIndex(where: { $0.id == DefaultProfiles.chromiumProfileId }),
           !oldConfig.profiles[chromiumIndex].bundleIds.contains(DefaultProfiles.vivaldiBundleId) {
            oldConfig.profiles[chromiumIndex].bundleIds.append(DefaultProfiles.vivaldiBundleId)
        }
        if let chromiumIndex = oldConfig.profiles.firstIndex(where: { $0.id == DefaultProfiles.chromiumProfileId }) {
            oldConfig.profiles[chromiumIndex].bundleIds.removeAll { $0 == DefaultProfiles.diaBundleId }
            if !oldConfig.profiles[chromiumIndex].bundleIds.contains(DefaultProfiles.arcBundleId) {
                oldConfig.profiles[chromiumIndex].bundleIds.append(DefaultProfiles.arcBundleId)
            }
        }
        oldConfig.profiles[0].rules[0].gesture = "D"
        oldConfig.profiles[0].rules[0].label = "Old new tab"
        store.current = oldConfig

        let migratedStore = ConfigStore(fileURL: url)
        let matcher = ProfileMatcher(configStore: migratedStore)

        expect(migratedStore.current.defaultsRevision == 8, "Config migration updates defaults revision")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "D")?.label == "Close tab", "Config migration installs down close")
        expect(matcher.match(bundleId: "com.google.Chrome", gesture: "U")?.label == "New tab", "Config migration installs up open")
        expect(matcher.profile(for: DefaultProfiles.vivaldiBundleId)?.name == "Vivaldi", "Config migration moves Vivaldi to Vivaldi profile")
        expect(migratedStore.current.profiles.first(where: { $0.id == DefaultProfiles.chromiumProfileId })?.bundleIds.contains(DefaultProfiles.vivaldiBundleId) == false, "Config migration removes Vivaldi from Chromium profile")
        expect(matcher.profile(for: DefaultProfiles.diaBundleId)?.name == "Dia", "Config migration moves Dia to Dia profile")
        expect(matcher.match(bundleId: DefaultProfiles.diaBundleId, gesture: "R")?.action == .diaTab(.next), "Config migration installs Dia menu tab action")
        expect(migratedStore.current.profiles.first(where: { $0.id == DefaultProfiles.chromiumProfileId })?.bundleIds.contains(DefaultProfiles.diaBundleId) == false, "Config migration removes Dia from Chromium profile")
        expect(migratedStore.current.profiles.first(where: { $0.id == DefaultProfiles.chromiumProfileId })?.bundleIds.contains(DefaultProfiles.arcBundleId) == false, "Config migration removes Arc from Chromium profile")
    }

    private static func validateConfigImportExport() {
        let sourceURL = temporaryConfigURL()
        let exportURL = temporaryConfigURL()
        let importedURL = temporaryConfigURL()

        let sourceStore = ConfigStore(fileURL: sourceURL)
        sourceStore.current.profiles[0].name = "Custom Chromium"
        sourceStore.current.trigger = TriggerConfig(
            button: .other,
            requiredModifiers: [.control],
            otherButtonNumber: 5
        )

        do {
            try sourceStore.exportConfig(to: exportURL)

            let importedStore = ConfigStore(fileURL: importedURL)
            try importedStore.importConfig(from: exportURL)

            expect(importedStore.current.profiles[0].name == "Custom Chromium", "Config import/export preserves profile edits")
            expect(importedStore.current.trigger == sourceStore.current.trigger, "Config import/export preserves trigger edits")
        } catch {
            failures.append("Config import/export threw: \(error.localizedDescription)")
        }
    }

    private static func token(
        _ tuples: [(CGFloat, CGFloat)],
        _ config: RecognitionConfig
    ) -> String {
        GesturePathRecognizer.token(
            for: tuples.map { CGPoint(x: $0.0, y: $0.1) },
            config: config
        )
    }

    private static func mouseEvent(
        type: CGEventType,
        button: CGMouseButton,
        modifiers: [ModifierKey] = []
    ) -> CGEvent {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: .zero,
            mouseButton: button
        )

        guard let event else {
            fatalError("Failed to create mouse event")
        }

        event.flags = CGEventFlags.from(modifiers)
        return event
    }

    private static func otherMouseEvent(
        type: CGEventType,
        buttonNumber: Int,
        modifiers: [ModifierKey] = []
    ) -> CGEvent {
        let event = mouseEvent(type: type, button: .center, modifiers: modifiers)
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(buttonNumber))
        return event
    }

    private static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            failures.append(message)
        }
    }

    private static func temporaryConfigURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
