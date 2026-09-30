import AppKit
import Foundation
import PetitCafeKit
import Observation

@MainActor
@Observable
final class UpdateController {
    private(set) var state: UpdateState = .idle
    private(set) var plan: UpdatePlan?

    private let currentVersion: AppVersion?
    private let fetcher: ReleaseFetcher
    private let downloader: UpdateDownloader
    private let installer: UpdateInstaller
    private var prefs = Preferences()
    private var downloadTask: Task<Void, Never>?
    private var downloadID: UUID?
    private var downloadedDMG: URL?

    init(
        fetcher: ReleaseFetcher = ReleaseFetcher(),
        downloader: UpdateDownloader = UpdateDownloader(),
        installer: UpdateInstaller = UpdateInstaller(),
        bundleVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    ) {
        self.fetcher = fetcher
        self.downloader = downloader
        self.installer = installer
        self.currentVersion = bundleVersion.flatMap(AppVersion.init)
    }

    var currentDisplayVersion: String { currentVersion.map(displayVersion) ?? "unknown" }

    func displayVersion(_ version: AppVersion) -> String {
        "\(version.major).\(version.minor).\(version.patch)"
    }

    // MARK: Check

    func checkNow(userInitiated: Bool) async {
        // A check must not reset a download or a second check that is already under way.
        guard !state.blocksNewCheck else {
            if userInitiated, state != .checking { UpdateWindowController.shared.show(controller: self) }
            return
        }

        // Fail safe: an unparseable own version can't be compared, so never report a spurious update.
        guard let current = currentVersion else {
            state = .idle
            if userInitiated { showUpToDate() }
            return
        }

        state = .checking
        let releases: [GitHubRelease]
        do {
            releases = try await fetcher.fetchReleases()
        } catch {
            state = .failed(error.localizedDescription)
            if userInitiated { showFailure(error.localizedDescription) }
            return
        }

        guard let plan = UpdateAvailability.plan(current: current, releases: releases) else {
            self.plan = nil
            state = .idle
            if userInitiated { showUpToDate() }
            return
        }

        self.plan = plan
        state = .available
        guard UpdatePromptGate.shouldPrompt(
            latest: plan.version,
            skipped: prefs.skippedUpdateVersion.flatMap(AppVersion.init),
            interactive: userInitiated) else { return }
        UpdateWindowController.shared.show(controller: self)
    }

    /// Menu action: reopen the window if a plan is already in hand, else check.
    func showWindowOrCheck() async {
        if plan != nil {
            UpdateWindowController.shared.show(controller: self)
            return
        }
        await checkNow(userInitiated: true)
    }

    /// About button: always asks GitHub again, so a plan cached since launch can't hide a newer release.
    func checkFromAbout() async {
        await checkNow(userInitiated: true)
    }

    // MARK: Window actions

    func startDownload() {
        guard let plan else { return }
        downloadTask?.cancel()
        // A cancelled task finishes late; only the task that still owns the download may set state.
        let id = UUID()
        downloadID = id
        state = .downloading(received: 0, total: plan.size)
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let dmg = try await downloader.downloadToTemp(
                    dmgURL: plan.dmgURL, expectedSize: plan.size,
                    onProgress: { received, total in
                        Task { @MainActor in
                            guard self.downloadID == id, case .downloading = self.state else { return }
                            self.state = .downloading(received: received, total: total)
                        }
                    })
                if let expected = plan.sha256 {
                    let actual = try await Task.detached { try FileDigest.sha256(of: dmg) }.value
                    guard actual == expected else {
                        try? FileManager.default.removeItem(at: dmg)
                        if downloadID == id {
                            state = .failed("The download didn't match the checksum GitHub published.")
                        }
                        return
                    }
                }
                guard downloadID == id else {
                    try? FileManager.default.removeItem(at: dmg)
                    return
                }
                downloadedDMG = dmg
                state = .readyToInstall
            } catch is CancellationError {
                if downloadID == id { state = .available }
            } catch let error as URLError where error.code == .cancelled {
                if downloadID == id { state = .available }
            } catch {
                if downloadID == id { state = .failed(error.localizedDescription) }
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadID = nil
        state = .available
    }

    func installAndRelaunch() {
        guard let dmg = downloadedDMG, let plan else { return }
        do {
            let installedPath = try installer.install(dmgAt: dmg, expectedVersion: displayVersion(plan.version))
            downloadedDMG = nil
            // relaunch() terminates this instance; applicationWillTerminate releases the
            // keep-awake first, and the spawned script reopens the new copy.
            installer.relaunch(path: installedPath)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func skipThisVersion() {
        if let plan { prefs.skippedUpdateVersion = displayVersion(plan.version) }
        dismissWindow()
    }

    func dismissWindow() { UpdateWindowController.shared.close() }

    /// Closing the window abandons an in-flight download; the plan is kept so the
    /// menu item can reopen without re-checking.
    func windowClosed() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadID = nil
        if case .downloading = state { state = .available }
        if case .failed = state { state = .available }
    }

    // MARK: Alerts (interactive checks only)

    private func showUpToDate() {
        present(
            style: .informational, title: "You're up to date",
            text: "Petit Café \(currentDisplayVersion) is the latest version.")
    }

    private func showFailure(_ message: String) {
        present(style: .warning, title: "Update check failed", text: message)
    }

    // A modal alert run from inside an async function holds up every other main-actor job until
    // it is dismissed, including a café ending. Handing it to the run loop keeps those moving.
    private func present(style: NSAlert.Style, title: String, text: String) {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated {
                NSApplication.shared.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.alertStyle = style
                alert.messageText = title
                alert.informativeText = text
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
