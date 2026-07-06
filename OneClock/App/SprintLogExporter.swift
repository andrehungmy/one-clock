import AppKit

/// Menu-bar entry points for the sprint log: export via save panel, clear
/// with confirmation. AppKit-only glue; formatting lives in SprintLogExport.
@MainActor
enum SprintLogExporter {
    static func exportMarkdown(entries: [SprintLogEntry]) {
        save(content: SprintLogExport.markdown(entries: entries), fileExtension: "md")
    }

    static func exportJSON(entries: [SprintLogEntry]) {
        save(content: SprintLogExport.json(entries: entries), fileExtension: "json")
    }

    /// Shows the destructive confirmation and returns whether the user chose
    /// to clear. The caller performs the actual clear so observable state
    /// stays in sync.
    static func confirmClear(count: Int) -> Bool {
        guard count > 0 else {
            return false
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear sprint log?"
        alert.informativeText = "This permanently removes \(count) logged sprint\(count == 1 ? "" : "s"). Export first if you want to keep them."
        alert.addButton(withTitle: "Clear Log")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func save(content: String, fileExtension: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "one-clock-log-\(formatter.string(from: Date())).\(fileExtension)"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Export failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
