import Foundation

/// The parts of installing an update that decide whether the user still has an app afterwards.
public enum UpdateInstall {
    public enum Failure: Error, Equatable { case unexpectedApp }

    /// The mounted app must be the expected product and version before it replaces anything.
    public static func verify(app: URL, bundleIdentifier: String, version: String) throws {
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard
            info?["CFBundleIdentifier"] as? String == bundleIdentifier,
            info?["CFBundleShortVersionString"] as? String == version
        else { throw Failure.unexpectedApp }
    }

    /// Copies `source` next to `installed`, then swaps it in. A copy that fails leaves the
    /// installed app untouched and no staging folder behind.
    public static func replace(
        installed: URL,
        with source: URL,
        stagingName: String,
        fileManager: FileManager = .default,
        copy: (_ source: URL, _ staging: URL) throws -> Void
    ) throws {
        let staging = installed.deletingLastPathComponent().appendingPathComponent(stagingName)
        do {
            try copy(source, staging)
            if fileManager.fileExists(atPath: installed.path) {
                _ = try fileManager.replaceItemAt(installed, withItemAt: staging)
            } else {
                try fileManager.moveItem(at: staging, to: installed)
            }
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }
}
