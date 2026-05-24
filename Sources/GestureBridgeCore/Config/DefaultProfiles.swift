import Foundation

enum DefaultProfiles {
    static let revision = 8
    static let vivaldiBundleId = "com.vivaldi.Vivaldi"
    static let diaBundleId = "company.thebrowser.dia"
    static let arcBundleId = "company.thebrowser.Browser"
    static let vivaldiProfileId = uuid("2EC54551-BC4F-4D88-8FA8-9D5E2E15F9B4")
    static let diaProfileId = uuid("8B67C67F-184D-4207-A45C-A9D6BC0EED6A")
    static let chromiumProfileId = uuid("A0B929C6-97D5-4385-B636-3C9E0291E957")

    static func makeConfig() -> AppConfig {
        AppConfig(
            defaultsRevision: revision,
            enabled: true,
            launchAtLogin: false,
            browserOnlyMode: true,
            trigger: TriggerConfig(button: .right, requiredModifiers: []),
            recognition: RecognitionConfig(
                minimumMovementPx: 22,
                segmentThresholdPx: 12,
                jitterTolerancePx: 6,
                maxGestureDurationMs: 1200
            ),
            profiles: [
                vivaldiProfile(),
                diaProfile(),
                chromiumProfile(),
                safariProfile(),
                firefoxProfile()
            ],
            blockedBundleIds: [
                "com.apple.finder",
                "com.apple.Terminal",
                "com.googlecode.iterm2",
                "com.todesktop.230313mzl4w4u92"
            ],
            showGestureOverlay: false
        )
    }

    private static func vivaldiProfile() -> BrowserProfile {
        BrowserProfile(
            id: vivaldiProfileId,
            name: "Vivaldi",
            bundleIds: [vivaldiBundleId],
            enabled: true,
            rules: browserRules(
                previousTab: .vivaldiTab(.previousByOrder),
                nextTab: .vivaldiTab(.nextByOrder)
            )
        )
    }

    private static func diaProfile() -> BrowserProfile {
        BrowserProfile(
            id: diaProfileId,
            name: "Dia",
            bundleIds: [diaBundleId],
            enabled: true,
            rules: browserRules(
                previousTab: .diaTab(.previous),
                nextTab: .diaTab(.next)
            )
        )
    }

    private static func chromiumProfile() -> BrowserProfile {
        BrowserProfile(
            id: chromiumProfileId,
            name: "Chromium browsers",
            bundleIds: [
                "com.google.Chrome",
                "com.google.Chrome.canary",
                "com.brave.Browser",
                "com.microsoft.edgemac",
                "com.operasoftware.Opera"
            ],
            enabled: true,
            rules: browserRules(
                previousTab: shortcut(.leftArrow, [.command, .option]),
                nextTab: shortcut(.rightArrow, [.command, .option])
            )
        )
    }

    private static func safariProfile() -> BrowserProfile {
        BrowserProfile(
            id: uuid("F6D98EDB-77C6-421D-B44B-C5FF77EEC2AF"),
            name: "Safari",
            bundleIds: ["com.apple.Safari"],
            enabled: true,
            rules: browserRules(
                previousTab: shortcut(.tab, [.control, .shift]),
                nextTab: shortcut(.tab, [.control])
            )
        )
    }

    private static func firefoxProfile() -> BrowserProfile {
        BrowserProfile(
            id: uuid("0EA52F07-EE26-4F79-AE44-D52A42A0194D"),
            name: "Firefox",
            bundleIds: ["org.mozilla.firefox"],
            enabled: true,
            rules: browserRules(
                previousTab: shortcut(.tab, [.control, .shift]),
                nextTab: shortcut(.tab, [.control])
            )
        )
    }

    private static func browserRules(
        previousTab: GestureAction,
        nextTab: GestureAction
    ) -> [GestureRule] {
        [
            rule("65D6F587-6C7C-4D66-8D39-17985A6F77F1", "U", "New tab", shortcut(.t, [.command])),
            rule("D9DAF1E0-7C39-44A4-A9E2-E9D2A6FCF0F6", "D", "Close tab", shortcut(.w, [.command])),
            rule("1D2B4193-4EC5-4188-AE08-E2C5C7995A1D", "DU", "Reopen closed tab", shortcut(.t, [.command, .shift])),
            rule("801F2E11-9988-476D-BFB0-0D8FC63F67E6", "L", "Previous tab", previousTab),
            rule("99BB7ED2-7C2E-4E5E-B6AA-6969B52F9F1F", "R", "Next tab", nextTab),
            rule("24FE7C6A-2776-484E-A236-65F1F8D4A01F", "UL", "Back", shortcut(.leftArrow, [.command])),
            rule("7A348E96-3466-4D00-B093-6A8E7DB82C0B", "UR", "Forward", shortcut(.rightArrow, [.command])),
            rule("F2A01AC3-B8D8-4840-8C8F-9798E0271EAB", "UD", "Reload", shortcut(.r, [.command]))
        ]
    }

    private static func rule(
        _ id: String,
        _ gesture: String,
        _ label: String,
        _ action: GestureAction
    ) -> GestureRule {
        GestureRule(
            id: uuid(id),
            gesture: gesture,
            label: label,
            action: action
        )
    }

    private static func shortcut(_ key: KeyCodeToken, _ modifiers: [ModifierKey]) -> GestureAction {
        .shortcut(ShortcutAction(key: key, modifiers: modifiers))
    }

    private static func uuid(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Invalid built-in UUID: \(value)")
        }

        return uuid
    }
}
