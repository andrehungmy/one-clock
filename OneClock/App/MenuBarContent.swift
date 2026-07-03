import AppKit
import SwiftUI

struct MenuBarContent: View {
    let appState: AppState

    var body: some View {
        Button("Show One Clock", systemImage: "macwindow") {
            appState.showPanel()
        }

        Button("Hide One Clock", systemImage: "eye.slash") {
            appState.hidePanel()
        }
        .disabled(!appState.isPanelVisible)

        Divider()

        Button("Quit One Clock", systemImage: "power") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
