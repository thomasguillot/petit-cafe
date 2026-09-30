import Foundation

public protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func enable() throws
    func disable() throws
}

public enum LaunchAtLogin {
    public static let defaultAppliedKey = "launchAtLoginDefaultApplied"

    /// Returns what to tell the user when the change did not take effect, or nil when it did.
    public static func apply(_ desired: Bool, to item: LoginItemControlling) -> String? {
        applyChange(desired, to: item)
    }

    /// Turns launch at login on once, the first time the installed app runs. After that the
    /// choice belongs to the user: turning it off in the menu is never undone.
    public static func enableByDefault(
        _ item: LoginItemControlling,
        defaults: UserDefaults,
        isInstalled: Bool
    ) {
        guard isInstalled, !defaults.bool(forKey: defaultAppliedKey) else { return }
        defaults.set(true, forKey: defaultAppliedKey)
        if !item.isEnabled { try? item.enable() }
    }

    private static func applyChange(_ desired: Bool, to item: LoginItemControlling) -> String? {
        do {
            if desired { try item.enable() } else { try item.disable() }
            // macOS can accept the request yet leave the item waiting for approval.
            guard item.isEnabled == desired else {
                return "Launch at login needs your approval in System Settings, under General, Login Items."
            }
            return nil
        } catch {
            let verb = desired ? "enable" : "disable"
            return "Couldn't \(verb) launch at login: \(error.localizedDescription)"
        }
    }
}
