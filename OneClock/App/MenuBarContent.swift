import AppKit
import SwiftUI

struct MenuBarContent: View {
    let appState: AppState

    private var session: SprintSessionController {
        appState.sprintSession
    }

    private var sprintHeader: String? {
        guard session.lifecycleState != .setup else {
            return nil
        }

        let trimmed = session.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Untitled Sprint" : trimmed
        return "\(title) — \(SprintStatusPresentation(phase: session.lifecycleState).label)"
    }

    var body: some View {
        let commands = SprintMenuCommands(session: session)

        if let sprintHeader {
            Text(sprintHeader)
            Divider()
        }

        Button(appState.isPanelVisible ? "Hide One Clock" : "Show One Clock",
               systemImage: appState.isPanelVisible ? "eye.slash" : "macwindow") {
            appState.togglePanel()
        }
        .keyboardShortcut(.space, modifiers: [.control, .option])

        Divider()

        Button("Start Sprint", systemImage: "play.fill") {
            session.start()
            appState.showPanel()
        }
        .disabled(!commands.canStart)

        if commands.canResume {
            Button("Resume Sprint", systemImage: "play.fill") {
                session.resume()
            }
        } else {
            Button("Pause Sprint", systemImage: "pause.fill") {
                session.pause()
            }
            .disabled(!commands.canPause)
        }

        Button("Finish Sprint", systemImage: "stop.fill") {
            session.finish()
            appState.showPanel()
        }
        .disabled(!commands.canFinish)

        Divider()

        Button("New Sprint", systemImage: "plus.circle.fill") {
            session.newSprint()
            appState.showPanel()
        }
        .disabled(!commands.canCreateNewSprint)

        Button("Reset Sprint", systemImage: "arrow.counterclockwise") {
            session.reset()
            appState.showPanel()
        }
        .disabled(!commands.canReset)

        Divider()

        let loggedCount = session.logEntries.count
        Menu("Sprint Log") {
            Text(loggedCount == 1 ? "1 sprint logged" : "\(loggedCount) sprints logged")

            Divider()

            Button("Export as Markdown…", systemImage: "doc.text") {
                SprintLogExporter.exportMarkdown(entries: session.logEntries)
            }
            .disabled(loggedCount == 0)

            Button("Export as JSON…", systemImage: "curlybraces") {
                SprintLogExporter.exportJSON(entries: session.logEntries)
            }
            .disabled(loggedCount == 0)

            Divider()

            Button("Clear Log…", systemImage: "trash") {
                if SprintLogExporter.confirmClear(count: session.logEntries.count) {
                    session.clearLog()
                }
            }
            .disabled(loggedCount == 0)
        }

        Divider()

        Button("Show Tutorial", systemImage: "questionmark.circle") {
            UserDefaults.standard.set(true, forKey: FloatingPanelView.tutorialRequestedDefaultsKey)
            appState.showPanel()
        }

        Button("Quit One Clock", systemImage: "power") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
