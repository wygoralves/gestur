import Combine
import Foundation

final class ConfigStore: ObservableObject {
    @Published var current: AppConfig {
        didSet {
            save()
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? ConfigStore.defaultConfigURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let loaded = Self.load(from: self.fileURL, decoder: self.decoder) {
            self.current = Self.migratedConfig(from: loaded)
        } else {
            self.current = DefaultProfiles.makeConfig()
            save()
        }
    }

    func resetToDefaults() {
        current = DefaultProfiles.makeConfig()
    }

    func addCurrentApp(bundleId: String, name: String?) {
        guard !bundleId.isEmpty else { return }

        var updated = current
        let profileName = name.map { "\($0) profile" } ?? bundleId
        let ruleTemplate = updated.profiles.first?.rules ?? []

        if updated.profiles.contains(where: { $0.bundleIds.contains(bundleId) }) {
            return
        }

        updated.profiles.append(
            BrowserProfile(
                id: UUID(),
                name: profileName,
                bundleIds: [bundleId],
                enabled: true,
                rules: ruleTemplate
            )
        )

        current = updated
    }

    func block(bundleId: String) {
        guard !bundleId.isEmpty else { return }

        var updated = current

        if !updated.blockedBundleIds.contains(bundleId) {
            updated.blockedBundleIds.append(bundleId)
            updated.blockedBundleIds.sort()
        }

        current = updated
    }

    func profileName(for bundleId: String?) -> String {
        guard let bundleId else {
            return "None"
        }

        return current.profile(for: bundleId)?.name ?? "None"
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = try encoder.encode(current)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("GestureBridge failed to save config: \(error.localizedDescription)")
        }
    }

    private static func load(from fileURL: URL, decoder: JSONDecoder) -> AppConfig? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? decoder.decode(AppConfig.self, from: data)
    }

    private static func migratedConfig(from loaded: AppConfig) -> AppConfig {
        guard loaded.defaultsRevision != DefaultProfiles.revision else {
            return loaded
        }

        let defaults = DefaultProfiles.makeConfig()
        var migrated = loaded

        for defaultProfile in defaults.profiles {
            if let index = migrated.profiles.firstIndex(where: { $0.id == defaultProfile.id }) {
                let existing = migrated.profiles[index]
                migrated.profiles[index] = BrowserProfile(
                    id: existing.id,
                    name: existing.name,
                    bundleIds: existing.bundleIds,
                    enabled: existing.enabled,
                    rules: defaultProfile.rules
                )
            } else {
                migrated.profiles.append(defaultProfile)
            }
        }

        migrated.defaultsRevision = DefaultProfiles.revision
        return migrated
    }

    private static func defaultConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appendingPathComponent("GestureBridge", isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
