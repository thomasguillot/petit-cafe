import Foundation

@MainActor
public final class AwakeSession {
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    public private(set) var active: Cafe?
    public private(set) var endDate: Date?
    public var onChange: (() -> Void)?

    public var isOn: Bool { active != nil }

    // The session ends a timed café itself; the system timeout only matters if the app is stuck,
    // so it is set a little later to never cut a café short.
    static let systemTimeoutGrace: TimeInterval = 30

    private(set) var expiry: Task<Void, Never>?
    private let preventer: any SleepPreventing
    private let now: () -> Date
    private let sleep: Sleep

    public init(
        preventer: any SleepPreventing,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0, clock: .continuous) }
    ) {
        self.preventer = preventer
        self.now = now
        self.sleep = sleep
    }

    public func serve(_ cafe: Cafe) {
        start(cafe, for: cafe.seconds)
    }

    /// Picks a café back up where it left off: a timed café runs until its original end date,
    /// and one whose end date has passed is left off.
    public func resume(_ cafe: Cafe, until endDate: Date?) {
        guard cafe.seconds != nil else {
            start(cafe, for: nil)
            return
        }
        guard let remaining = endDate?.timeIntervalSince(now()), remaining > 0 else { return }
        start(cafe, for: remaining)
    }

    private func start(_ cafe: Cafe, for seconds: TimeInterval?) {
        expiry?.cancel()
        expiry = nil

        guard preventer.prevent(timeout: seconds.map { $0 + Self.systemTimeoutGrace }) else {
            active = nil
            endDate = nil
            onChange?()
            return
        }

        active = cafe
        endDate = seconds.map { now().addingTimeInterval($0) }

        if let seconds {
            let sleep = sleep
            expiry = Task { [weak self] in
                try? await sleep(.seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        }
        onChange?()
    }

    public func stop() {
        expiry?.cancel()
        expiry = nil
        preventer.allow()
        active = nil
        endDate = nil
        onChange?()
    }
}
