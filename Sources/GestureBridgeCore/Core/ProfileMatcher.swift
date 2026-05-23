import Foundation

final class ProfileMatcher {
    private let configStore: ConfigStore
    private var cachedConfig: AppConfig?
    private var profileCache: [String: BrowserProfile?] = [:]

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func profile(for bundleId: String) -> BrowserProfile? {
        let config = configStore.current
        refreshCacheIfNeeded(config)

        if let cached = profileCache[bundleId] {
            return cached
        }

        let profile = config.profile(for: bundleId)
        profileCache[bundleId] = profile
        return profile
    }

    func match(bundleId: String, gesture: String) -> GestureRule? {
        guard configStore.current.enabled,
              !configStore.current.blockedBundleIds.contains(bundleId)
        else {
            return nil
        }

        return profile(for: bundleId)?
            .rules
            .first { $0.gesture == gesture }
    }

    private func refreshCacheIfNeeded(_ config: AppConfig) {
        guard cachedConfig != config else {
            return
        }

        cachedConfig = config
        profileCache.removeAll(keepingCapacity: true)
    }
}
