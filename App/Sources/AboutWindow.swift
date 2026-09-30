import AppKit
import SwiftUI

/// Hosts the About window. An AppKit shell for the same reason as the update window: the app has
/// no SwiftUI scene to open it from.
@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func show(update: UpdateController) {
        if let window {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingView(rootView: AboutView().environment(update))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "About Petit Café"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.delegate = self
        window.center()
        self.window = window
        // Accessory app: windows open behind the frontmost app without this.
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

struct AboutView: View {
    @Environment(UpdateController.self) private var update
    @AppStorage("autoCheckForUpdates") private var autoCheckForUpdates = true

    private var year: String { String(Calendar.current.component(.year, from: Date())) }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Petit Café")
                .font(.title2.weight(.semibold))
            Text("Version \(update.currentDisplayVersion)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Check for Updates…") {
                Task { await update.checkFromAbout() }
            }
            .padding(.top, 6)
            Toggle("Automatically check for updates on launch", isOn: $autoCheckForUpdates)
                .toggleStyle(.checkbox)
                .font(.callout)
            Text("© \(year) Thomas Guillot · MIT-Licensed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(.horizontal, 36)
        .padding(.top, 40)
        .padding(.bottom, 28)
        .fixedSize()
    }
}
