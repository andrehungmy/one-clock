import Foundation
import Testing
@testable import OneClock

@Suite("Sprint Log")
struct SprintLogTests {
    private let utc = TimeZone(identifier: "UTC")!

    private func entry(
        _ title: String,
        planned: TimeInterval,
        invested: TimeInterval,
        at date: Date
    ) -> SprintLogEntry {
        SprintLogEntry(
            id: UUID(),
            title: title,
            plannedDuration: planned,
            investedDuration: invested,
            completedAt: date
        )
    }

    // 2026-07-04 08:00:00 UTC
    private let morning: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 8))!
    }()

    @Test("UserDefaults log store appends, round-trips, and clears")
    func userDefaultsLogStoreRoundTrips() throws {
        let suiteName = "OneClockTests.log.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSprintLogStore(defaults: defaults)

        #expect(store.entries().isEmpty)

        let first = entry("Sprint 1", planned: 900, invested: 2, at: morning)
        let second = entry("跑步", planned: 5_999, invested: 1_086, at: morning.addingTimeInterval(3_600))
        store.append(first)
        store.append(second)

        #expect(store.entries() == [first, second])

        store.clear()
        #expect(store.entries().isEmpty)
    }

    @Test("Auto naming counts up from the last auto-named entry")
    func autoNamingCountsUp() {
        #expect(SprintAutoNaming.nextName(after: []) == "Sprint 1")

        let afterAuto = [entry("Sprint 3", planned: 900, invested: 900, at: morning)]
        #expect(SprintAutoNaming.nextName(after: afterAuto) == "Sprint 4")

        let afterCustom = [
            entry("Sprint 3", planned: 900, invested: 900, at: morning),
            entry("跑步", planned: 900, invested: 900, at: morning.addingTimeInterval(60)),
        ]
        #expect(SprintAutoNaming.nextName(after: afterCustom) == "Sprint 1")

        let lookalikes = [entry("Sprint 3 extra", planned: 900, invested: 900, at: morning)]
        #expect(SprintAutoNaming.nextName(after: lookalikes) == "Sprint 1")
    }

    @Test("Markdown export groups by day, morning to night")
    func markdownExportGroupsByDay() {
        let previousEvening = morning.addingTimeInterval(-12 * 3_600) // 2026-07-03 20:00 UTC
        let entries = [
            entry("跑步", planned: 5_999, invested: 1_086, at: morning.addingTimeInterval(3_600)),
            entry("Sprint 1", planned: 900, invested: 2, at: morning),
            entry("Warmup", planned: 300, invested: 310, at: previousEvening),
        ]

        let markdown = SprintLogExport.markdown(entries: entries, timeZone: utc)

        let expected = """
        # One Clock — Sprint Log

        ## 20260703

        - Warmup — Planned 05:00 · Complete 05:10

        ## 20260704

        - Sprint 1 — Planned 15:00 · Complete 00:02
        - 跑步 — Planned 99:59 · Complete 18:06

        """
        #expect(markdown == expected)
    }

    @Test("Markdown export handles an empty log")
    func markdownExportHandlesEmptyLog() {
        let markdown = SprintLogExport.markdown(entries: [], timeZone: utc)
        #expect(markdown.contains("No sprints logged yet."))
    }

    @Test("JSON export carries day grouping and both time representations")
    func jsonExportCarriesDayGroupingAndTimes() {
        let entries = [
            entry("Sprint 1", planned: 900, invested: 2, at: morning),
        ]

        let json = SprintLogExport.json(entries: entries, timeZone: utc)

        #expect(json.contains("\"date\" : \"20260704\""))
        #expect(json.contains("\"title\" : \"Sprint 1\""))
        #expect(json.contains("\"planned\" : \"15:00\""))
        #expect(json.contains("\"plannedSeconds\" : 900"))
        #expect(json.contains("\"complete\" : \"00:02\""))
        #expect(json.contains("\"completeSeconds\" : 2"))
        #expect(json.contains("\"completedAt\" : \"2026-07-04T08:00:00Z\""))
    }
}

@MainActor
@Suite("Sprint completion logging and notifications")
struct SprintCompletionLoggingTests {
    private let baseDate = Date(timeIntervalSinceReferenceDate: 9_000)

    @Test("Untitled sprints auto-name as Sprint N from the log")
    func untitledSprintsAutoName() {
        let log = InMemorySprintLog()
        log.append(SprintLogEntry(
            id: UUID(), title: "Sprint 2", plannedDuration: 900, investedDuration: 900, completedAt: baseDate
        ))
        let controller = SprintSessionController(
            plannedDuration: 900,
            clock: ManualLogClock(now: baseDate),
            ticker: ManualLogTicker(),
            logStore: log
        )

        controller.start()

        #expect(controller.taskTitle == "Sprint 3")
        #expect(controller.lifecycleState == .running)
    }

    @Test("Untitled start with an empty log begins at Sprint 1")
    func untitledStartBeginsAtSprintOne() {
        let fixture = makeController(plannedDuration: 900)

        fixture.controller.start()

        #expect(fixture.controller.taskTitle == "Sprint 1")
    }

    @Test("A custom title is kept as-is")
    func customTitleIsKept() {
        let fixture = makeController(plannedDuration: 900)
        fixture.controller.updateTaskTitle("Deep work")

        fixture.controller.start()

        #expect(fixture.controller.taskTitle == "Deep work")
    }

    @Test("Finishing logs the original planned duration even after +5m")
    func finishingLogsOriginalPlannedDuration() throws {
        let fixture = makeController(plannedDuration: 900)
        fixture.controller.updateTaskTitle("Deep work")

        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(300)
        fixture.ticker.emit(fixture.clock.now)
        fixture.controller.addFiveMinutes()
        fixture.clock.now = baseDate.addingTimeInterval(420)
        fixture.ticker.emit(fixture.clock.now)
        fixture.controller.finish()

        let logged = try #require(fixture.log.entries().last)
        #expect(logged.title == "Deep work")
        #expect(logged.plannedDuration == 900)
        #expect(logged.investedDuration == 420)
        #expect(logged.completedAt == fixture.clock.now)
        #expect(fixture.log.entries().count == 1)
    }

    @Test("Observable log entries mirror the store across load, append, and clear")
    func logEntriesMirrorStore() {
        let log = InMemorySprintLog()
        log.append(SprintLogEntry(
            id: UUID(), title: "Sprint 1", plannedDuration: 900, investedDuration: 850, completedAt: baseDate
        ))

        let clock = ManualLogClock(now: baseDate)
        let ticker = ManualLogTicker()
        let controller = SprintSessionController(
            plannedDuration: 600,
            clock: clock,
            ticker: ticker,
            logStore: log
        )
        #expect(controller.logEntries.count == 1)

        controller.updateTaskTitle("Deep work")
        controller.start()
        clock.now = baseDate.addingTimeInterval(60)
        ticker.emit(clock.now)
        controller.finish()

        #expect(controller.logEntries.count == 2)
        #expect(controller.logEntries == log.entries())

        controller.clearLog()
        #expect(controller.logEntries.isEmpty)
        #expect(log.entries().isEmpty)
    }

    @Test("Renaming mid-sprint updates the sprint and the eventual log entry")
    func renamingMidSprintPropagates() throws {
        let fixture = makeController(plannedDuration: 900)
        fixture.controller.updateTaskTitle("Draft")
        fixture.controller.start()

        fixture.clock.now = baseDate.addingTimeInterval(60)
        fixture.ticker.emit(fixture.clock.now)
        fixture.controller.updateTaskTitle("Draft v2")

        #expect(fixture.controller.sprint?.taskTitle == "Draft v2")

        fixture.controller.finish()
        let logged = try #require(fixture.log.entries().last)
        #expect(logged.title == "Draft v2")
    }

    @Test("Renaming on the result screen rewrites the completed log entry")
    func renamingAfterCompletionRewritesLogEntry() throws {
        let fixture = makeController(plannedDuration: 900)
        fixture.controller.updateTaskTitle("Draft")
        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(60)
        fixture.ticker.emit(fixture.clock.now)
        fixture.controller.finish()

        fixture.controller.updateTaskTitle("Shipped the draft")

        let logged = try #require(fixture.log.entries().last)
        #expect(logged.title == "Shipped the draft")
        #expect(fixture.controller.logEntries.last?.title == "Shipped the draft")
        #expect(fixture.log.entries().count == 1)
    }

    @Test("Renaming a log entry directly updates only that entry")
    func renamingLogEntryDirectly() throws {
        let fixture = makeController(plannedDuration: 60)
        fixture.controller.updateTaskTitle("First")
        fixture.controller.start()
        fixture.controller.finish()
        fixture.controller.newSprint()
        fixture.controller.updateTaskTitle("Second")
        fixture.controller.start()
        fixture.controller.finish()

        let first = try #require(fixture.controller.logEntries.first)
        fixture.controller.renameLogEntry(id: first.id, to: "First (renamed)")

        #expect(fixture.controller.logEntries.map(\.title) == ["First (renamed)", "Second"])
        #expect(fixture.log.entries().map(\.title) == ["First (renamed)", "Second"])
        #expect(fixture.controller.logEntries.first?.plannedDuration == first.plannedDuration)
    }

    @Test("Time-up notification fires once when entering overtime")
    func timeUpNotificationFiresOnce() {
        let fixture = makeController(plannedDuration: 60)
        fixture.controller.updateTaskTitle("Focus")

        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(61)
        fixture.ticker.emit(fixture.clock.now)
        fixture.clock.now = baseDate.addingTimeInterval(90)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.notifier.timeUpTitles == ["Focus"])
    }

    @Test("Restoring an overtime sprint does not renotify")
    func restoreDoesNotRenotify() {
        let persistence = InMemoryActiveSprintStore()
        var overtime = Sprint(taskTitle: "Long haul", plannedDuration: 60)
        overtime.phase = .overtimeRunning
        overtime.originalStartedAt = baseDate.addingTimeInterval(-120)
        overtime.activeSegmentStartedAt = baseDate.addingTimeInterval(-120)
        persistence.save(overtime)

        let notifier = SpyNotifier()
        _ = SprintSessionController(
            clock: ManualLogClock(now: baseDate),
            ticker: ManualLogTicker(),
            store: persistence,
            notifier: notifier
        )

        #expect(notifier.timeUpTitles.isEmpty)
    }

    private func makeController(plannedDuration: TimeInterval) -> LogFixture {
        let clock = ManualLogClock(now: baseDate)
        let ticker = ManualLogTicker()
        let log = InMemorySprintLog()
        let notifier = SpyNotifier()
        let controller = SprintSessionController(
            plannedDuration: plannedDuration,
            clock: clock,
            ticker: ticker,
            notifier: notifier,
            logStore: log
        )

        return LogFixture(clock: clock, ticker: ticker, log: log, notifier: notifier, controller: controller)
    }
}

@MainActor
private struct LogFixture {
    let clock: ManualLogClock
    let ticker: ManualLogTicker
    let log: InMemorySprintLog
    let notifier: SpyNotifier
    let controller: SprintSessionController
}

private final class ManualLogClock: SprintClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class ManualLogTicker: SprintTicking {
    private var onTick: (@MainActor (Date) -> Void)?
    private(set) var isTicking = false

    func start(_ onTick: @escaping @MainActor (Date) -> Void) {
        guard !isTicking else {
            return
        }
        self.onTick = onTick
        isTicking = true
    }

    func stop() {
        onTick = nil
        isTicking = false
    }

    func emit(_ date: Date) {
        onTick?(date)
    }
}

private final class InMemorySprintLog: SprintLogStoring {
    private var stored: [SprintLogEntry] = []

    func entries() -> [SprintLogEntry] {
        stored
    }

    func append(_ entry: SprintLogEntry) {
        stored.append(entry)
    }

    func overwrite(_ entries: [SprintLogEntry]) {
        stored = entries
    }

    func clear() {
        stored.removeAll()
    }
}

private final class InMemoryActiveSprintStore: SprintStoring {
    private var stored: Sprint?

    func load() -> Sprint? {
        stored
    }

    func save(_ sprint: Sprint?) {
        stored = sprint
    }
}

@MainActor
private final class SpyNotifier: SprintNotifying {
    private(set) var timeUpTitles: [String] = []
    private(set) var prepareCount = 0

    func prepareAuthorization() {
        prepareCount += 1
    }

    func notifyTimeUp(taskTitle: String) {
        timeUpTitles.append(taskTitle)
    }
}
