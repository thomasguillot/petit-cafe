import Foundation

struct Preferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private enum Keys {
        static let autoCheckForUpdates = "autoCheckForUpdates"
        static let skippedUpdateVersion = "skippedUpdateVersion"
    }

    // nil = nothing skipped. Silences background update prompts up to this
    // version only; a newer release prompts again and a manual check always does.
    var skippedUpdateVersion: String? {
        get { defaults.string(forKey: Keys.skippedUpdateVersion) }
        set { defaults.set(newValue, forKey: Keys.skippedUpdateVersion) }
    }

    // Written by the About window's checkbox through @AppStorage, under the same key.
    var autoCheckForUpdates: Bool {
        if defaults.object(forKey: Keys.autoCheckForUpdates) == nil { return true }
        return defaults.bool(forKey: Keys.autoCheckForUpdates)
    }
}
