import Foundation

final class ProfileMatcher {
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func profile(for bundleId: String) -> BrowserProfile? {
        configStore.current.profile(for: bundleId)
    }

    func match(bundleId: String, gesture: String) -> GestureRule? {
        guard configStore.current.isEnabledForBundleId(bundleId) else {
            return nil
        }

        return configStore.current.profile(for: bundleId)?
            .rules
            .first { $0.gesture == gesture }
    }
}
