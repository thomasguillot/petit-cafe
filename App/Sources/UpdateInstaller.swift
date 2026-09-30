import AppKit
import Foundation
import PetitCafeKit

/// Installs a downloaded update in place: mount the `.dmg`, check it holds the expected app, copy
/// it next to the installed one, strip quarantine, swap the two, and relaunch. The already-trusted
/// running app performs the swap itself, so Gatekeeper doesn't re-challenge the relaunch once
/// quarantine is cleared.
@MainActor
struct UpdateInstaller {
    enum InstallError: LocalizedError {
        case missingApp
        case unexpectedApp
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingApp:
                return "The update disk image doesn't contain Petit Café."
            case .unexpectedApp:
                return "The update disk image doesn't contain the expected version of Petit Café."
            case let .commandFailed(detail):
                return detail
            }
        }
    }

    // Hardcoded /Applications (not the running bundle path) so an app launched
    // from a translocated or read-only location still installs correctly.
    private let appName = "Petit Café.app"
    private let installedPath = "/Applications/Petit Café.app"
    private let bundleIdentifier = "com.petitcafe.app"

    /// Returns the installed path. Does not relaunch — the caller confirms, then calls
    /// `relaunch(path:)`.
    func install(dmgAt dmg: URL, expectedVersion: String) throws -> String {
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("petitcafe-update-\(UUID().uuidString)")
        try shell("/usr/bin/hdiutil",
                  ["attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint.path])
        defer { _ = try? shell("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"]) }

        let newApp = mountPoint.appendingPathComponent(appName)
        guard FileManager.default.fileExists(atPath: newApp.path) else { throw InstallError.missingApp }
        do {
            try UpdateInstall.verify(app: newApp, bundleIdentifier: bundleIdentifier, version: expectedVersion)
        } catch {
            throw InstallError.unexpectedApp
        }

        try UpdateInstall.replace(
            installed: URL(fileURLWithPath: installedPath),
            with: newApp,
            stagingName: ".petitcafe-update-\(UUID().uuidString).app"
        ) { source, staging in
            try shell("/usr/bin/ditto", [source.path, staging.path])
            // Downloaded apps carry com.apple.quarantine; strip it or Gatekeeper
            // re-blocks the relaunch.
            _ = try? shell("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staging.path])
        }

        try? FileManager.default.removeItem(at: dmg)
        return installedPath
    }

    func relaunch(path: String) {
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/bin/sh")
        script.arguments = UpdateRelaunch.arguments(
            pid: ProcessInfo.processInfo.processIdentifier, appPath: path)
        try? script.run()
        NSApplication.shared.terminate(nil)
    }

    @discardableResult
    private func shell(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        // Read before waiting: a child that fills the pipe would otherwise never exit.
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw InstallError.commandFailed("\((path as NSString).lastPathComponent) failed: \(output)")
        }
        return output
    }
}
