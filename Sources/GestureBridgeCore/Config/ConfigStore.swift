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
            let migrated = Self.migratedConfig(from: loaded)
            self.current = migrated
            if migrated != loaded {
                save()
            }
        } else if let legacy = Self.load(from: Self.legacyConfigURL(), decoder: self.decoder) {
            self.current = Self.migratedConfig(from: legacy)
            save()
        } else {
            self.current = DefaultProfiles.makeConfig()
            save()
        }
    }

    func resetToDefaults() {
        current = DefaultProfiles.makeConfig()
    }

    func exportConfig(to destinationURL: URL) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(current)
        try data.write(to: destinationURL, options: [.atomic])
    }

    func importConfig(from sourceURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let imported = try decoder.decode(AppConfig.self, from: data)
        current = Self.migratedConfig(from: imported)
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
            NSLog("Gestur failed to save config: \(error.localizedDescription)")
        }
    }

    private static func load(from fileURL: URL, decoder: JSONDecoder) -> AppConfig? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? decoder.decode(AppConfig.self, from: data)
    }

    private static func migratedConfig(from loaded: AppConfig) -> AppConfig {
        let loadedRevision = loaded.defaultsRevision ?? 0

        guard loadedRevision != DefaultProfiles.revision else {
            return loaded
        }

        let defaults = DefaultProfiles.makeConfig()
        var migrated = loaded

        if loadedRevision < 3 {
            migrateVivaldiProfile(in: &migrated, defaults: defaults)
        }

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

    private static func migrateVivaldiProfile(in config: inout AppConfig, defaults: AppConfig) {
        for index in config.profiles.indices where config.profiles[index].id != DefaultProfiles.vivaldiProfileId {
            config.profiles[index].bundleIds.removeAll { $0 == DefaultProfiles.vivaldiBundleId }
        }

        if let index = config.profiles.firstIndex(where: { $0.id == DefaultProfiles.vivaldiProfileId }) {
            if !config.profiles[index].bundleIds.contains(DefaultProfiles.vivaldiBundleId) {
                config.profiles[index].bundleIds.append(DefaultProfiles.vivaldiBundleId)
            }
            return
        }

        guard let vivaldiProfile = defaults.profiles.first(where: { $0.id == DefaultProfiles.vivaldiProfileId }) else {
            return
        }

        let insertionIndex = config.profiles.firstIndex { $0.id == DefaultProfiles.chromiumProfileId } ?? 0
        config.profiles.insert(vivaldiProfile, at: insertionIndex)
    }

    private static func defaultConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appendingPathComponent("Gestur", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private static func legacyConfigURL() -> URL {
        let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return supportURL
            .appendingPathComponent("GestureBridge", isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
