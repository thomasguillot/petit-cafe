public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case available
    case downloading(received: Int, total: Int)
    case readyToInstall
    case failed(String)

    /// A new check must not reset a check, a download or a pending install already under way.
    public var blocksNewCheck: Bool {
        switch self {
        case .checking, .downloading, .readyToInstall: true
        case .idle, .available, .failed: false
        }
    }
}
