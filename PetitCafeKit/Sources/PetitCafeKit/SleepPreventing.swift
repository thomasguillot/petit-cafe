import Foundation
import IOKit.pwr_mgt

@MainActor
public protocol SleepPreventing {
    /// `timeout` asks the system to release the assertion on its own after that many seconds.
    func prevent(timeout: TimeInterval?) -> Bool
    func allow()
}

public final class IOKitSleepPreventer: SleepPreventing {
    private var assertionID: IOPMAssertionID?

    public init() {}

    public func prevent(timeout: TimeInterval?) -> Bool {
        allow()

        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            "Petit Café is keeping this Mac awake" as CFString,
            nil,
            nil,
            nil,
            timeout ?? 0,
            kIOPMAssertionTimeoutActionRelease as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { return false }

        assertionID = id
        return true
    }

    public func allow() {
        guard let id = assertionID else { return }
        IOPMAssertionRelease(id)
        assertionID = nil
    }

    /// How many power assertions this process holds, as the system sees it.
    static func assertionCount() -> Int {
        var assertions: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
              let byProcess = assertions?.takeRetainedValue() as? [NSNumber: [Any]]
        else { return 0 }
        return byProcess[NSNumber(value: ProcessInfo.processInfo.processIdentifier)]?.count ?? 0
    }
}
