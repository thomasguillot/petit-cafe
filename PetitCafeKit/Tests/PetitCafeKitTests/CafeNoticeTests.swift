import Testing
@testable import PetitCafeKit

struct CafeNoticeTests {
    @Test func noChangeMeansNoNotice() {
        #expect(CafeNotice.forChange(from: nil, to: nil, endTime: nil) == nil)
        #expect(CafeNotice.forChange(from: .double, to: .double, endTime: "14:30") == nil)
    }

    @Test func aTimedCafeSaysWhenItEnds() {
        let notice = CafeNotice.forChange(from: nil, to: .express, endTime: "14:30")

        #expect(notice == CafeNotice(title: "Express", body: "Keeping your Mac awake until 14:30."))
    }

    @Test func aVolonteSaysItRunsUntilSwitchedOff() {
        let notice = CafeNotice.forChange(from: .express, to: .aVolonte, endTime: nil)

        #expect(notice == CafeNotice(title: "À volonté", body: "Keeping your Mac awake until you switch it off."))
    }

    @Test func switchingOffSaysTheMacCanSleep() {
        let notice = CafeNotice.forChange(from: .allonge, to: nil, endTime: nil)

        #expect(notice == CafeNotice(title: "Petit Café", body: "Your Mac can sleep again."))
    }
}
