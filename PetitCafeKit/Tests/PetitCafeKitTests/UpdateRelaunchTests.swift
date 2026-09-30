import Foundation
import Testing
@testable import PetitCafeKit

struct UpdateRelaunchTests {
    @Test func waitsForThePidThenOpensTheFirstArgument() {
        let script = UpdateRelaunch.shellScript(pid: 4242)

        #expect(script.contains("/bin/kill -0 4242"))
        #expect(script.contains("-lt 150"))
        #expect(script.hasSuffix("/usr/bin/open \"$1\""))
    }

    @Test func thePathIsPassedAsAnArgumentNotInterpolated() {
        let path = "/Applications/Petit Café $(touch /tmp/x).app"
        let arguments = UpdateRelaunch.arguments(pid: 7, appPath: path)

        #expect(arguments.count == 4)
        #expect(arguments[0] == "-c")
        #expect(!arguments[1].contains("Petit"))
        #expect(arguments[3] == path)
    }

    @Test func theScriptOpensWhatItIsGiven() throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("relaunch-\(UUID().uuidString)")
        let script = UpdateRelaunch.shellScript(pid: 2_000_000_000).replacingOccurrences(of: "/usr/bin/open", with: "/usr/bin/touch")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "test", marker.path]
        try process.run()
        process.waitUntilExit()
        defer { try? FileManager.default.removeItem(at: marker) }

        #expect(FileManager.default.fileExists(atPath: marker.path))
    }
}
