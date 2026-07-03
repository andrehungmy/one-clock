import SwiftUI

@main
struct OneClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("One Clock", systemImage: "timer") {
            MenuBarContent(appState: appState)
        }
        .menuBarExtraStyle(.menu)
    }
}
