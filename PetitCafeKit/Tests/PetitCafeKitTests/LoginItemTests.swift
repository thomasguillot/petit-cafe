import Foundation
import Testing
@testable import PetitCafeKit

private final class MockLoginItem: LoginItemControlling {
    var enabled = false
    var ignoresRequests = false
    var enableError: Error?
    var disableError: Error?
    var isEnabled: Bool { enabled }

    func enable() throws {
        if let enableError { throw enableError }
        if !ignoresRequests { enabled = true }
    }

    func disable() throws {
        if let disableError { throw disableError }
        enabled = false
    }
}

private struct Boom: Error {}

struct LaunchAtLoginDefaultTests {
    let defaults: UserDefaults

    init() {
        let suite = "PetitCafeKitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func theFirstInstalledRunTurnsItOn() {
        let item = MockLoginItem()

        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: true)

        #expect(item.isEnabled)
    }

    @Test func turningItOffAfterwardsIsRespectedOnLaterRuns() {
        let item = MockLoginItem()
        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: true)
        item.enabled = false

        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: true)

        #expect(!item.isEnabled)
    }

    @Test func aCopyOutsideApplicationsIsLeftAloneUntilInstalled() {
        let item = MockLoginItem()

        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: false)
        #expect(!item.isEnabled)

        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: true)
        #expect(item.isEnabled)
    }

    @Test func aFailedFirstAttemptIsNotRetried() {
        let item = MockLoginItem()
        item.enableError = Boom()
        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: true)
        item.enableError = nil

        LaunchAtLogin.enableByDefault(item, defaults: defaults, isInstalled: true)

        #expect(!item.isEnabled)
    }
}

struct LaunchAtLoginTests {
    @Test func enablingReportsEnabledWithNoError() {
        let item = MockLoginItem()

        let result = LaunchAtLogin.apply(true, to: item)

        #expect(item.isEnabled)
        #expect(result == nil)
    }

    @Test func disablingReportsDisabledWithNoError() {
        let item = MockLoginItem()
        item.enabled = true

        let result = LaunchAtLogin.apply(false, to: item)

        #expect(!item.isEnabled)
        #expect(result == nil)
    }

    @Test func anEnableThatDoesNotTakeEffectIsReported() {
        let item = MockLoginItem()
        item.ignoresRequests = true

        let result = LaunchAtLogin.apply(true, to: item)

        #expect(!item.isEnabled)
        #expect(result?.contains("Login Items") == true)
    }

    @Test func aFailedEnableReportsTheRealStatusAndAnError() {
        let item = MockLoginItem()
        item.enableError = Boom()

        let result = LaunchAtLogin.apply(true, to: item)

        #expect(!item.isEnabled)
        #expect(result?.contains("enable") == true)
    }

    @Test func aFailedDisableReportsTheRealStatusAndAnError() {
        let item = MockLoginItem()
        item.enabled = true
        item.disableError = Boom()

        let result = LaunchAtLogin.apply(false, to: item)

        #expect(item.isEnabled)
        #expect(result?.contains("disable") == true)
    }
}
