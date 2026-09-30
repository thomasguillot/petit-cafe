public struct CafeNotice: Equatable, Sendable {
    public let title: String
    public let body: String

    /// The notice for a change of café, or nil when nothing changed. `endTime` is the formatted
    /// time a timed café ends at.
    public static func forChange(from previous: Cafe?, to current: Cafe?, endTime: String?) -> CafeNotice? {
        guard previous != current else { return nil }

        guard let current else {
            return CafeNotice(title: "Petit Café", body: "Your Mac can sleep again.")
        }
        guard let endTime else {
            return CafeNotice(title: current.name, body: "Keeping your Mac awake until you switch it off.")
        }
        return CafeNotice(title: current.name, body: "Keeping your Mac awake until \(endTime).")
    }
}
