import Foundation
import Testing
@testable import PetitCafeKit

struct UpdateInstallTests {
    let root: URL
    let fileManager = FileManager.default

    init() throws {
        root = fileManager.temporaryDirectory.appendingPathComponent("UpdateInstallTests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func makeApp(_ name: String, identifier: String = "com.petitcafe.app", version: String) throws -> URL {
        let app = root.appendingPathComponent(name)
        try fileManager.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let info: NSDictionary = ["CFBundleIdentifier": identifier, "CFBundleShortVersionString": version]
        try info.write(to: app.appendingPathComponent("Contents/Info.plist"))
        return app
    }

    private func version(of app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }

    @Test func theExpectedAppPassesVerification() throws {
        let app = try makeApp("New.app", version: "1.1.0")

        try UpdateInstall.verify(app: app, bundleIdentifier: "com.petitcafe.app", version: "1.1.0")
    }

    @Test func aDifferentAppOrVersionIsRejected() throws {
        let stale = try makeApp("Stale.app", version: "1.0.0")
        let other = try makeApp("Other.app", identifier: "com.example.other", version: "1.1.0")

        #expect(throws: UpdateInstall.Failure.unexpectedApp) {
            try UpdateInstall.verify(app: stale, bundleIdentifier: "com.petitcafe.app", version: "1.1.0")
        }
        #expect(throws: UpdateInstall.Failure.unexpectedApp) {
            try UpdateInstall.verify(app: other, bundleIdentifier: "com.petitcafe.app", version: "1.1.0")
        }
        #expect(throws: UpdateInstall.Failure.unexpectedApp) {
            try UpdateInstall.verify(
                app: root.appendingPathComponent("Missing.app"), bundleIdentifier: "com.petitcafe.app", version: "1.1.0")
        }
    }

    @Test func theNewAppReplacesTheInstalledOne() throws {
        let installed = try makeApp("Petit Café.app", version: "1.0.0")
        let new = try makeApp("New.app", version: "1.1.0")

        try UpdateInstall.replace(installed: installed, with: new, stagingName: ".staging.app") {
            try fileManager.copyItem(at: $0, to: $1)
        }

        #expect(version(of: installed) == "1.1.0")
        #expect(!fileManager.fileExists(atPath: root.appendingPathComponent(".staging.app").path))
    }

    @Test func aFirstInstallLandsAtTheInstalledPath() throws {
        let installed = root.appendingPathComponent("Petit Café.app")
        let new = try makeApp("New.app", version: "1.1.0")

        try UpdateInstall.replace(installed: installed, with: new, stagingName: ".staging.app") {
            try fileManager.copyItem(at: $0, to: $1)
        }

        #expect(version(of: installed) == "1.1.0")
    }

    @Test func aFailedCopyLeavesTheInstalledAppAlone() throws {
        struct CopyFailed: Error {}
        let installed = try makeApp("Petit Café.app", version: "1.0.0")
        let new = try makeApp("New.app", version: "1.1.0")

        #expect(throws: CopyFailed.self) {
            try UpdateInstall.replace(installed: installed, with: new, stagingName: ".staging.app") { _, staging in
                try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
                throw CopyFailed()
            }
        }

        #expect(version(of: installed) == "1.0.0")
        #expect(!fileManager.fileExists(atPath: root.appendingPathComponent(".staging.app").path))
    }
}

struct FileDigestTests {
    @Test func hashesAFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("digest-\(UUID().uuidString)")
        try Data("abc".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(try FileDigest.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

struct UpdateStateTests {
    @Test func workInProgressBlocksANewCheck() {
        #expect(UpdateState.checking.blocksNewCheck)
        #expect(UpdateState.downloading(received: 1, total: 2).blocksNewCheck)
        #expect(UpdateState.readyToInstall.blocksNewCheck)
    }

    @Test func settledStatesAllowANewCheck() {
        #expect(!UpdateState.idle.blocksNewCheck)
        #expect(!UpdateState.available.blocksNewCheck)
        #expect(!UpdateState.failed("x").blocksNewCheck)
    }
}
