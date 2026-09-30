import Foundation

/// The café that was active when the app quit to install an update, left for the relaunched app
/// to pick up.
public struct CafeHandover: Equatable, Sendable {
    public let cafe: Cafe
    public let endDate: Date?

    public init(cafe: Cafe, endDate: Date?) {
        self.cafe = cafe
        self.endDate = endDate
    }

    public static let cafeKey = "handoverCafe"
    public static let endDateKey = "handoverEndDate"
    public static let savedAtKey = "handoverSavedAt"

    // A relaunch takes seconds. Anything older was left by a relaunch that never happened, and
    // must not switch a café back on at some later launch.
    public static let maxAge: TimeInterval = 5 * 60

    public static func save(_ cafe: Cafe?, endDate: Date?, defaults: UserDefaults, now: Date) {
        guard let cafe else {
            clear(defaults)
            return
        }
        defaults.set(cafe.rawValue, forKey: cafeKey)
        defaults.set(endDate, forKey: endDateKey)
        defaults.set(now, forKey: savedAtKey)
    }

    public static func take(defaults: UserDefaults, now: Date) -> CafeHandover? {
        defer { clear(defaults) }
        guard
            let cafe = defaults.string(forKey: cafeKey).flatMap(Cafe.init(rawValue:)),
            let savedAt = defaults.object(forKey: savedAtKey) as? Date,
            now.timeIntervalSince(savedAt) <= maxAge
        else { return nil }

        return CafeHandover(cafe: cafe, endDate: defaults.object(forKey: endDateKey) as? Date)
    }

    private static func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: cafeKey)
        defaults.removeObject(forKey: endDateKey)
        defaults.removeObject(forKey: savedAtKey)
    }
}
