import Foundation
import Testing
@testable import PetitCafeKit

struct CafeHandoverTests {
    let defaults: UserDefaults
    let reference = Date(timeIntervalSince1970: 1_000_000)

    init() {
        let suite = "PetitCafeKitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func aSavedCafeComesBackWithItsEndDate() {
        let endDate = reference.addingTimeInterval(20 * 60)
        CafeHandover.save(.noisette, endDate: endDate, defaults: defaults, now: reference)

        let handover = CafeHandover.take(defaults: defaults, now: reference.addingTimeInterval(5))

        #expect(handover == CafeHandover(cafe: .noisette, endDate: endDate))
    }

    @Test func aVolonteComesBackWithNoEndDate() {
        CafeHandover.save(.aVolonte, endDate: nil, defaults: defaults, now: reference)

        let handover = CafeHandover.take(defaults: defaults, now: reference.addingTimeInterval(5))

        #expect(handover == CafeHandover(cafe: .aVolonte, endDate: nil))
    }

    @Test func aHandoverIsTakenOnlyOnce() {
        CafeHandover.save(.aVolonte, endDate: nil, defaults: defaults, now: reference)
        _ = CafeHandover.take(defaults: defaults, now: reference)

        #expect(CafeHandover.take(defaults: defaults, now: reference) == nil)
    }

    @Test func nothingSavedGivesNothing() {
        #expect(CafeHandover.take(defaults: defaults, now: reference) == nil)
    }

    @Test func savingNothingClearsAnEarlierHandover() {
        CafeHandover.save(.aVolonte, endDate: nil, defaults: defaults, now: reference)
        CafeHandover.save(nil, endDate: nil, defaults: defaults, now: reference)

        #expect(CafeHandover.take(defaults: defaults, now: reference) == nil)
    }

    @Test func aHandoverLeftFromAFailedRelaunchIsIgnored() {
        CafeHandover.save(.aVolonte, endDate: nil, defaults: defaults, now: reference)

        let late = reference.addingTimeInterval(CafeHandover.maxAge + 1)

        #expect(CafeHandover.take(defaults: defaults, now: late) == nil)
        #expect(CafeHandover.take(defaults: defaults, now: reference) == nil)
    }
}
