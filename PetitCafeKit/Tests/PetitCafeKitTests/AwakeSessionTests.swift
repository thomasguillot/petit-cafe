import Foundation
import Testing
@testable import PetitCafeKit

@MainActor
final class FakePreventer: SleepPreventing {
    var succeeds = true
    var isPreventing = false
    var timeout: TimeInterval?

    func prevent(timeout: TimeInterval?) -> Bool {
        isPreventing = succeeds
        self.timeout = timeout
        return succeeds
    }

    func allow() {
        isPreventing = false
    }
}

@MainActor
struct AwakeSessionTests {
    let preventer = FakePreventer()
    let reference = Date(timeIntervalSince1970: 1_000_000)

    func makeSession(
        sleep: @escaping AwakeSession.Sleep = { _ in try await Task.sleep(for: .seconds(3600)) }
    ) -> AwakeSession {
        AwakeSession(preventer: preventer, now: { [reference] in reference }, sleep: sleep)
    }

    @Test func startsOff() {
        let session = makeSession()

        #expect(!session.isOn)
        #expect(session.endDate == nil)
        #expect(!preventer.isPreventing)
    }

    @Test func servingATimedCafeKeepsTheMacAwakeUntilTheEndDate() {
        let session = makeSession()

        session.serve(.noisette)

        #expect(session.active == .noisette)
        #expect(session.endDate == reference.addingTimeInterval(30 * 60))
        #expect(preventer.isPreventing)
        #expect(preventer.timeout == 30 * 60 + AwakeSession.systemTimeoutGrace)
    }

    @Test func aVolonteHasNoEndDate() {
        let session = makeSession()

        session.serve(.aVolonte)

        #expect(session.isOn)
        #expect(session.endDate == nil)
        #expect(session.expiry == nil)
        #expect(preventer.timeout == nil)
    }

    @Test func stoppingLetsTheMacSleepAgain() {
        let session = makeSession()
        session.serve(.allonge)

        session.stop()

        #expect(!session.isOn)
        #expect(session.endDate == nil)
        #expect(!preventer.isPreventing)
    }

    @Test func aTimedCafeEndsOnItsOwn() async {
        let session = makeSession(sleep: { _ in })
        var changes = 0
        session.onChange = { changes += 1 }

        session.serve(.expresso)
        await session.expiry?.value

        #expect(!session.isOn)
        #expect(!preventer.isPreventing)
        #expect(changes == 2)
    }

    @Test func orderingAnotherCafeCancelsThePreviousExpiry() async {
        let session = makeSession()
        session.serve(.expresso)
        let first = session.expiry

        session.serve(.aVolonte)
        await first?.value

        #expect(session.active == .aVolonte)
        #expect(preventer.isPreventing)
    }

    @Test func aFailureWhileAnotherCafeIsActiveSwitchesOff() {
        let session = makeSession()
        session.serve(.expresso)
        preventer.succeeds = false

        session.serve(.double)

        #expect(!session.isOn)
        #expect(session.endDate == nil)
        #expect(!preventer.isPreventing)
    }

    @Test func staysOffWhenTheAssertionFails() {
        preventer.succeeds = false
        let session = makeSession()

        session.serve(.allonge)

        #expect(!session.isOn)
        #expect(session.expiry == nil)
    }
}

@MainActor
@Suite(.serialized)
struct IOKitSleepPreventerTests {
    @Test func createsAndReleasesARealAssertion() {
        let preventer = IOKitSleepPreventer()

        let before = IOKitSleepPreventer.assertionCount()

        #expect(preventer.prevent(timeout: nil))
        #expect(IOKitSleepPreventer.assertionCount() == before + 1)
        #expect(preventer.prevent(timeout: 60))
        #expect(IOKitSleepPreventer.assertionCount() == before + 1)
        preventer.allow()
        #expect(IOKitSleepPreventer.assertionCount() == before)
    }
}
