import Foundation

/// One completed sprint: what it was called, what was planned (the original
/// input, not later extensions), and what was actually invested.
struct SprintLogEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let plannedDuration: TimeInterval
    let investedDuration: TimeInterval
    let completedAt: Date
}

protocol SprintLogStoring {
    func entries() -> [SprintLogEntry]
    func append(_ entry: SprintLogEntry)
    func overwrite(_ entries: [SprintLogEntry])
    func clear()
}

struct UserDefaultsSprintLogStore: SprintLogStoring {
    static let defaultKey = "sprintLog"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = UserDefaultsSprintLogStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func entries() -> [SprintLogEntry] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SprintLogEntry].self, from: data) else {
            return []
        }

        return decoded
    }

    func append(_ entry: SprintLogEntry) {
        overwrite(entries() + [entry])
    }

    func overwrite(_ entries: [SprintLogEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

enum SprintAutoNaming {
    private static let prefix = "Sprint "

    /// Default name for an untitled sprint. Counts up from the most recent
    /// logged entry ("Sprint 3" → "Sprint 4"); a custom name or a cleared log
    /// restarts the sequence at "Sprint 1".
    static func nextName(after entries: [SprintLogEntry]) -> String {
        guard let last = entries.last, let number = autoNumber(from: last.title) else {
            return "Sprint 1"
        }

        return "\(prefix)\(number + 1)"
    }

    static func autoNumber(from title: String) -> Int? {
        guard title.hasPrefix(prefix) else {
            return nil
        }

        let digits = title.dropFirst(prefix.count)
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else {
            return nil
        }

        return Int(digits)
    }
}

enum SprintLogExport {
    /// Markdown grouped by day (yyyyMMdd headers), entries morning → night.
    static func markdown(entries: [SprintLogEntry], timeZone: TimeZone = .current) -> String {
        var output = "# One Clock — Sprint Log\n"

        guard !entries.isEmpty else {
            return output + "\nNo sprints logged yet.\n"
        }

        for day in dayGroups(entries: entries, timeZone: timeZone) {
            output += "\n## \(day.date)\n\n"
            for entry in day.entries {
                let planned = SprintTimeFormatter.minutesAndSeconds(entry.plannedDuration)
                let invested = SprintTimeFormatter.minutesAndSeconds(entry.investedDuration)
                output += "- \(entry.title) — Planned \(planned) · Complete \(invested)\n"
            }
        }

        return output
    }

    static func json(entries: [SprintLogEntry], timeZone: TimeZone = .current) -> String {
        let timestampFormatter = ISO8601DateFormatter()
        let days = dayGroups(entries: entries, timeZone: timeZone).map { day in
            ExportDay(date: day.date, sprints: day.entries.map { entry in
                ExportSprint(
                    title: entry.title,
                    planned: SprintTimeFormatter.minutesAndSeconds(entry.plannedDuration),
                    plannedSeconds: Int(entry.plannedDuration.rounded()),
                    complete: SprintTimeFormatter.minutesAndSeconds(entry.investedDuration),
                    completeSeconds: Int(entry.investedDuration.rounded()),
                    completedAt: timestampFormatter.string(from: entry.completedAt)
                )
            })
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(ExportRoot(days: days)),
              let text = String(data: data, encoding: .utf8) else {
            return "{ \"days\": [] }"
        }

        return text
    }

    private struct ExportRoot: Encodable {
        let days: [ExportDay]
    }

    private struct ExportDay: Encodable {
        let date: String
        let sprints: [ExportSprint]
    }

    private struct ExportSprint: Encodable {
        let title: String
        let planned: String
        let plannedSeconds: Int
        let complete: String
        let completeSeconds: Int
        let completedAt: String
    }

    /// Chronological day buckets (yyyyMMdd), entries morning → night within
    /// each day. Shared by the exporters and the panel's log sidebar.
    static func dayGroups(
        entries: [SprintLogEntry],
        timeZone: TimeZone = .current
    ) -> [(date: String, entries: [SprintLogEntry])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd"

        let sorted = entries.sorted { $0.completedAt < $1.completedAt }
        var days: [(date: String, entries: [SprintLogEntry])] = []
        for entry in sorted {
            let key = formatter.string(from: entry.completedAt)
            if days.last?.date == key {
                days[days.count - 1].entries.append(entry)
            } else {
                days.append((date: key, entries: [entry]))
            }
        }

        return days
    }
}
