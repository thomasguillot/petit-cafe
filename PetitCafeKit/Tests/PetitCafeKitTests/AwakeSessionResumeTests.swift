import Foundation
import Testing
@testable import PetitCafeKit

@MainActor
struct AwakeSessionResumeTests {
    let preventer = FakePreventer()
    let reference = Date(timeIntervalSince1970: 1_000_000)

    func makeSession(
        sleep: @escaping AwakeSession.Sleep = { _ in try await Task.sleep(for: .seconds(3600)) }
    ) -> AwakeSession {
        AwakeSession(preventer: preventer, now: { [reference] in reference }, sleep: sleep)
    }

    @Test func aResumedCafeKeepsItsEndDate() {
        let session = makeSession()
        let endDate = reference.addingTimeInterval(10 * 60)

        session.resume(.double, until: endDate)

        #expect(session.active == .double)
        #expect(session.endDate == endDate)
        #expect(preventer.isPreventing)
        #expect(preventer.timeout == 10 * 60 + AwakeSession.systemTimeoutGrace)
    }

    @Test func aResumedCafeEndsWhenItsTimeIsUp() async {
        let slept = Slept()
        let session = makeSession(sleep: { await slept.record($0) })

        session.resume(.double, until: reference.addingTimeInterval(10 * 60))
        await session.expiry?.value

        #expect(await slept.duration == .seconds(10 * 60))
        #expect(!session.isOn)
        #expect(!preventer.isPreventing)
    }

    @Test func aCafeThatEndedMeanwhileIsNotResumed() {
        let session = makeSession()
        var changes = 0
        session.onChange = { changes += 1 }

        session.resume(.expresso, until: reference.addingTimeInterval(-1))

        #expect(!session.isOn)
        #expect(!preventer.isPreventing)
        #expect(changes == 0)
    }

    @Test func aTimedCafeWithoutAnEndDateIsNotResumed() {
        let session = makeSession()

        session.resume(.expresso, until: nil)

        #expect(!session.isOn)
        #expect(!preventer.isPreventing)
    }

    @Test func aVolonteIsResumedWithNoEndDate() {
        let session = makeSession()

        session.resume(.aVolonte, until: nil)

        #expect(session.active == .aVolonte)
        #expect(session.endDate == nil)
        #expect(session.expiry == nil)
        #expect(preventer.timeout == nil)
    }
}

private actor Slept {
    var duration: Duration?
    func record(_ duration: Duration) { self.duration = duration }
}
