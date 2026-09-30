import AppKit
import PetitCafeKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let session = AwakeSession(preventer: IOKitSleepPreventer())
    private let loginItem: LoginItemControlling = SMAppServiceLoginItem()
    private let notifier = CafeNotifier()
    private let updateController = UpdateController()
    private lazy var updateScheduler = UpdateScheduler(controller: updateController)
    private var lastActive: Cafe?
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var menuIsOpen = false
    private var pinnedMenuWidth: CGFloat = 0
    private var isTerminating = false

    private var isInstalled: Bool { Bundle.main.bundlePath.contains("/Applications/") }

    // AppKit only reserves the tick column once an item is ticked, which shifts every item sideways.
    // An empty off-state image the size of the tick keeps the column there from the start.
    private let tickSpacer = NSImage(
        size: NSImage(named: NSImage.menuOnStateTemplateName)?.size ?? NSSize(width: 18, height: 17)
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        pinnedMenuWidth = widestWidth(of: menu)
        menu.minimumWidth = pinnedMenuWidth

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseDown, .rightMouseUp])
        statusItem = item

        session.onChange = { [weak self] in self?.sessionChanged() }
        resumeAfterUpdate()
        renderIcon()

        updateController.onWillRelaunch = { [weak self] in self?.leaveCafeForRelaunch() }
        updateScheduler.start()

        LaunchAtLogin.enableByDefault(
            loginItem,
            defaults: .standard,
            isInstalled: isInstalled
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        session.stop()
    }

    private func leaveCafeForRelaunch() {
        CafeHandover.save(session.active, endDate: session.endDate, defaults: .standard, now: Date())
    }

    // The café carries on from before the update, so there is no change to announce.
    private func resumeAfterUpdate() {
        guard let handover = CafeHandover.take(defaults: .standard, now: Date()) else { return }
        lastActive = handover.cafe
        session.resume(handover.cafe, until: handover.endDate)
        lastActive = session.active
    }

    @objc private func statusItemClicked() {
        if isSecondaryClick(NSApp.currentEvent) {
            toggleIndefinitely()
        } else {
            showMenu()
        }
    }

    // An accessibility press carries no event of its own, so `currentEvent` may be an older click.
    // Only a fresh mouse event on the cup itself counts; anything else opens the menu.
    private func isSecondaryClick(_ event: NSEvent?) -> Bool {
        guard
            let event,
            event.window === statusItem?.button?.window,
            ProcessInfo.processInfo.systemUptime - event.timestamp < 1
        else { return false }

        return event.type == .rightMouseUp
            || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
    }

    private func toggleIndefinitely() {
        if session.isOn {
            session.stop()
        } else {
            serve(.aVolonte)
        }
    }

    // Leaving the menu assigned would make AppKit open it on every click, the right one included.
    private func showMenu() {
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu, status: statusText)

        // The launch-time pin is measured with sample times; in locales whose digits differ in
        // width a real time can be wider, so the pin only ever grows.
        menu.minimumWidth = 0
        pinnedMenuWidth = max(pinnedMenuWidth, menu.size.width)
        menu.minimumWidth = pinnedMenuWidth
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    // A café can end while the menu is showing; update the rows in place rather than rebuild them
    // under the pointer.
    private func refreshOpenMenu() {
        guard menuIsOpen else { return }

        menu.items.first?.title = statusText
        for item in menu.items {
            guard let rawValue = item.representedObject as? String, let cafe = Cafe(rawValue: rawValue)
            else { continue }
            item.state = session.active == cafe ? .on : .off
        }
    }

    // The status line is the widest item only while a timed café runs, so the menu would change
    // width between states unless it is pinned to that case.
    private func widestWidth(of menu: NSMenu) -> CGFloat {
        let sampleHours = [10, 12, 20, 22]
        let widths = sampleHours.compactMap { hour -> CGFloat? in
            guard let date = Calendar.current.date(bySettingHour: hour, minute: 48, second: 0, of: Date())
            else { return nil }
            populate(menu, status: timedStatusText(until: date))
            return menu.size.width
        }
        return widths.max() ?? 0
    }

    private func populate(_ menu: NSMenu, status statusTitle: String) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        for cafe in Cafe.allCases {
            let item = NSMenuItem(title: cafe.name, action: #selector(order(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = cafe.rawValue
            item.badge = NSMenuItemBadge(string: cafe.durationLabel)
            item.state = session.active == cafe ? .on : .off
            item.offStateImage = tickSpacer
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let launch = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launch.target = self
        launch.state = loginItem.isEnabled ? .on : .off
        launch.offStateImage = tickSpacer
        menu.addItem(launch)

        menu.addItem(.separator())
        if let plan = updateController.plan {
            let update = NSMenuItem(
                title: "Update to \(updateController.displayVersion(plan.version))…",
                action: #selector(showUpdate),
                keyEquivalent: ""
            )
            update.target = self
            menu.addItem(update)
        }
        let about = NSMenuItem(title: "About Petit Café", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(
            withTitle: "Quit Petit Café",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
    }

    @objc private func order(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let cafe = Cafe(rawValue: rawValue) else {
            return
        }

        if session.active == cafe {
            session.stop()
        } else {
            serve(cafe)
        }
    }

    private func serve(_ cafe: Cafe) {
        session.serve(cafe)
        if !session.isOn {
            showAlert("Petit Café couldn't keep your Mac awake. macOS refused the request.")
        }
    }

    @objc private func showAbout() {
        AboutWindowController.shared.show(update: updateController)
    }

    @objc private func showUpdate() {
        Task { await updateController.showWindowOrCheck() }
    }

    @objc private func toggleLaunchAtLogin() {
        let desired = !loginItem.isEnabled
        // A login item registered from the disk image or a build folder points at a copy that
        // will not be there at the next login.
        guard !desired || isInstalled else {
            showAlert("Move Petit Café to your Applications folder first, then turn on Launch at Login.")
            return
        }

        if let error = LaunchAtLogin.apply(desired, to: loginItem) {
            showAlert(error)
        }
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func sessionChanged() {
        renderIcon()
        refreshOpenMenu()

        let notice = CafeNotice.forChange(
            from: lastActive,
            to: session.active,
            endTime: session.endDate.map(formattedTime)
        )
        lastActive = session.active
        if let notice, !isTerminating { notifier.post(notice) }
    }

    private var statusText: String {
        guard session.isOn else { return "Your Mac can sleep" }
        guard let endDate = session.endDate else { return "Keeping your Mac awake" }
        return timedStatusText(until: endDate)
    }

    private func timedStatusText(until endDate: Date) -> String {
        "Keeping your Mac awake until \(formattedTime(endDate))"
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func renderIcon() {
        guard let button = statusItem?.button else { return }

        button.image = NSImage(named: session.isOn ? "MenuBarIconOn" : "MenuBarIconOff")
        button.setAccessibilityLabel("Petit Café")
        button.setAccessibilityValue(session.isOn ? "On" : "Off")
        button.toolTip = session.isOn
            ? "Right-click to let your Mac sleep"
            : "Right-click to keep your Mac awake indefinitely"
    }
}
