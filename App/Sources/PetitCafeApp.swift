import SwiftUI

@main
struct PetitCafeApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {}
            }
    }
}
