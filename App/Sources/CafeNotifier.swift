import Foundation
import PetitCafeKit
import UserNotifications

@MainActor
final class CafeNotifier: NSObject, UNUserNotificationCenterDelegate {
    private var queue: Task<Void, Never>?
    private var latest = 0

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Posts run one after another, and a notice overtaken while waiting (for permission, or for
    // the one before it) is dropped, so the banner left on screen is always the current state.
    // Earlier notices are cleared rather than updated in place: an update to a delivered notice
    // does not reliably show a new banner.
    func post(_ notice: CafeNotice) {
        latest += 1
        let number = latest
        let previous = queue
        queue = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            guard number == latest else { return }

            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            center.removeAllDeliveredNotifications()
            try? await center.add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
