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
        expiry?.cancel()
        expiry = nil

        guard preventer.prevent(timeout: cafe.seconds.map { $0 + Self.systemTimeoutGrace }) else {
            active = nil
            endDate = nil
            onChange?()
            return
        }

        active = cafe
        endDate = cafe.seconds.map { now().addingTimeInterval($0) }

        if let seconds = cafe.seconds {
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
