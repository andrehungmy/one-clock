import SwiftUI

@main
struct OneClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(appState: appState)
        } label: {
            MenuBarLabel(session: appState.sprintSession)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarLabel: View {
    let session: SprintSessionController

    var body: some View {
        let phase = session.lifecycleState
        Image(systemName: SprintMenuBarPresentation.symbolName(for: phase))

        if let title = SprintMenuBarPresentation.title(
            for: phase,
            remainingTime: session.remainingTime,
            overtimeDuration: session.overtimeDuration
        ) {
            Text(title)
                .monospacedDigit()
        }
    }
}
