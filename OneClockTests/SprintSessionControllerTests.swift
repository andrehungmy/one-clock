import Foundation
import Testing
@testable import OneClock

@MainActor
@Suite("SprintSessionController")
struct SprintSessionControllerTests {
    private let baseDate = Date(timeIntervalSinceReferenceDate: 5_000)

    @Test("Starting and ticking updates display state from emitted dates")
    func startingAndTicking() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        #expect(fixture.store.lifecycleState == .running)
        #expect(fixture.ticker.startCallCount == 1)
        #expect(fixture.store.remainingTime == 600)

        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.store.elapsedTime == 120)
        #expect(fixture.store.remainingTime == 480)
    }

    @Test("Pause freezes displayed remaining time")
    func pauseFreezesDisplayedRemainingTime() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)
        fixture.store.pause()

        #expect(fixture.store.lifecycleState == .paused)
        #expect(fixture.store.remainingTime == 480)
        #expect(!fixture.ticker.isTicking)

        fixture.clock.now = baseDate.addingTimeInterval(420)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.store.elapsedTime == 120)
        #expect(fixture.store.remainingTime == 480)
    }

    @Test("Resume continues from the correct time")
    func resumeContinuesFromCorrectTime() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)
        fixture.store.pause()
        fixture.clock.now = baseDate.addingTimeInterval(300)
        fixture.store.resume()
        fixture.clock.now = baseDate.addingTimeInterval(360)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.store.lifecycleState == .running)
        #expect(fixture.store.elapsedTime == 180)
        #expect(fixture.store.remainingTime == 420)
    }

    @Test("Ticking transitions into overtime")
    func overtimeTransition() {
        let fixture = makeController(plannedDuration: 60)

        fixture.store.start()
        fixture.clock.now = baseDate.addingTimeInterval(60)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.store.lifecycleState == .overtimeRunning)
        #expect(fixture.store.remainingTime == 0)
        #expect(fixture.store.overtimeDuration == 0)
        #expect(fixture.ticker.isTicking)

        fixture.clock.now = baseDate.addingTimeInterval(75)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.store.isInOvertime)
        #expect(fixture.store.overtimeDuration == 15)
    }

    @Test("Add five minutes updates displayed remaining time")
    func addFiveMinutesBehavior() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)
        fixture.store.addFiveMinutes()

        #expect(fixture.store.lifecycleState == .running)
        #expect(fixture.store.elapsedTime == 120)
        #expect(fixture.store.remainingTime == 780)
        #expect(fixture.store.plannedDuration == 900)
    }

    @Test("Finish stops ticking and reset returns to idle setup")
    func finishAndResetBehavior() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)
        fixture.store.finish()

        #expect(fixture.store.lifecycleState == .completed)
        #expect(fixture.store.elapsedTime == 120)
        #expect(!fixture.ticker.isTicking)

        fixture.store.reset()

        #expect(fixture.store.lifecycleState == .setup)
        #expect(fixture.store.taskTitle.isEmpty)
        #expect(fixture.store.remainingTime == Sprint.defaultPlannedDuration)
        #expect(fixture.store.elapsedTime == 0)
    }

    @Test("New Sprint after completion returns to setup and retains prior values")
    func newSprintAfterCompletionRetainsPriorValues() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)
        fixture.store.finish()
        fixture.store.newSprint()

        #expect(fixture.store.lifecycleState == .setup)
        #expect(fixture.store.taskTitle == "Ship runtime")
        #expect(fixture.store.plannedDuration == 600)
        #expect(fixture.store.remainingTime == 600)

        fixture.store.reset()

        #expect(fixture.store.taskTitle.isEmpty)
        #expect(fixture.store.plannedDuration == Sprint.defaultPlannedDuration)
    }

    @Test("Repeated start and ticking do not create duplicate subscriptions")
    func repeatedStartDoesNotCreateDuplicateTicking() {
        let fixture = makeController(plannedDuration: 600)

        fixture.store.start()
        fixture.store.start()

        #expect(fixture.ticker.startCallCount == 1)
        #expect(fixture.store.lifecycleState == .running)

        fixture.clock.now = baseDate.addingTimeInterval(1)
        fixture.ticker.emit(fixture.clock.now)
        fixture.clock.now = baseDate.addingTimeInterval(2)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.ticker.startCallCount == 1)
        #expect(fixture.store.elapsedTime == 2)
        #expect(fixture.store.remainingTime == 598)
    }

    @Test("Reset is only offered when there is something to throw away")
    func resetAvailabilityTracksDirtyState() {
        let pristine = SprintSessionController(
            clock: ManualSprintClock(now: baseDate),
            ticker: ManualSprintTicker()
        )
        #expect(!pristine.canReset)

        pristine.updateTaskTitle("Draft brief")
        #expect(pristine.canReset)

        pristine.reset()
        #expect(!pristine.canReset)

        pristine.updatePlannedDuration(600)
        #expect(pristine.canReset)

        let fixture = makeController(plannedDuration: 600)
        fixture.store.start()
        #expect(fixture.store.canReset)

        fixture.store.finish()
        #expect(fixture.store.canReset)
    }

    private func makeController(plannedDuration: TimeInterval) -> Fixture {
        let clock = ManualSprintClock(now: baseDate)
        let ticker = ManualSprintTicker()
        let store = SprintSessionController(
            taskTitle: "Ship runtime",
            plannedDuration: plannedDuration,
            clock: clock,
            ticker: ticker
        )

        return Fixture(clock: clock, ticker: ticker, store: store)
    }
}

private struct Fixture {
    let clock: ManualSprintClock
    let ticker: ManualSprintTicker
    let store: SprintSessionController
}

private final class ManualSprintClock: SprintClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
private final class ManualSprintTicker: SprintTicking {
    private var onTick: (@MainActor (Date) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var isTicking = false

    func start(_ onTick: @escaping @MainActor (Date) -> Void) {
        guard !isTicking else {
            return
        }

        startCallCount += 1
        self.onTick = onTick
        isTicking = true
    }

    func stop() {
        guard isTicking else {
            return
        }

        stopCallCount += 1
        onTick = nil
        isTicking = false
    }

    func emit(_ date: Date) {
        guard isTicking else {
            return
        }

        onTick?(date)
    }
}

@MainActor
@Suite("SprintSessionController Persistence and Cues")
struct SprintSessionPersistenceTests {
    private let baseDate = Date(timeIntervalSinceReferenceDate: 5_000)

    @Test("Recovery snapshots pause active runtime states")
    func recoverySnapshotsPauseActiveRuntimeStates() {
        let fixture = makeController(plannedDuration: 600)

        fixture.controller.start()
        #expect(fixture.controller.lifecycleState == .running)
        #expect(fixture.persistence.savedSprint?.phase == .paused)

        fixture.controller.pause()
        #expect(fixture.persistence.savedSprint?.phase == .paused)

        fixture.controller.resume()
        #expect(fixture.controller.lifecycleState == .running)
        #expect(fixture.persistence.savedSprint?.phase == .paused)

        fixture.controller.finish()
        #expect(fixture.persistence.savedSprint?.phase == .completed)
    }

    @Test("Reset clears the persisted sprint")
    func resetClearsPersistedSprint() {
        let fixture = makeController(plannedDuration: 600)

        fixture.controller.start()
        fixture.controller.reset()

        #expect(fixture.persistence.savedSprint == nil)
    }

    @Test("A running heartbeat restores paused and excludes downtime")
    func runningHeartbeatRestoresPausedAndExcludesDowntime() throws {
        let fixture = makeController(plannedDuration: 600)
        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(30)
        fixture.ticker.emit(fixture.clock.now)
        let saved = try #require(fixture.persistence.savedSprint)

        let laterClock = ManualSprintClock(now: baseDate.addingTimeInterval(90))
        let restored = SprintSessionController(
            clock: laterClock,
            ticker: ManualSprintTicker(),
            store: fixture.persistence
        )

        #expect(saved.phase == .paused)
        #expect(restored.lifecycleState == .paused)
        #expect(restored.taskTitle == saved.taskTitle)
        #expect(restored.elapsedTime == 30)
        #expect(restored.remainingTime == 570)
        #expect(!restored.isTickerRunning)

        laterClock.now = baseDate.addingTimeInterval(100)
        restored.resume()

        #expect(restored.sprint?.accumulatedPausedDuration == 10)
        #expect(restored.elapsedTime == 30)
    }

    @Test("Recovery heartbeat writes every five seconds while running")
    func recoveryHeartbeatUsesFiveSecondInterval() throws {
        let fixture = makeController(plannedDuration: 600)
        fixture.controller.start()
        let savesAfterStart = fixture.persistence.saveCallCount

        fixture.clock.now = baseDate.addingTimeInterval(4)
        fixture.ticker.emit(fixture.clock.now)
        #expect(fixture.persistence.saveCallCount == savesAfterStart)

        fixture.clock.now = baseDate.addingTimeInterval(5)
        fixture.ticker.emit(fixture.clock.now)
        let saved = try #require(fixture.persistence.savedSprint)

        #expect(fixture.persistence.saveCallCount == savesAfterStart + 1)
        #expect(saved.phase == .paused)
        #expect(SprintEngine.focusedElapsedTime(for: saved, at: baseDate.addingTimeInterval(500)) == 5)
    }

    @Test("Normal termination saves an exact paused checkpoint")
    func normalTerminationSavesExactCheckpoint() throws {
        let fixture = makeController(plannedDuration: 600)
        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(2.5)

        fixture.controller.prepareForTermination()
        let saved = try #require(fixture.persistence.savedSprint)

        #expect(saved.phase == .paused)
        #expect(SprintEngine.focusedElapsedTime(for: saved, at: baseDate.addingTimeInterval(500)) == 2.5)
        #expect(SprintEngine.currentRemainingTime(for: saved, at: baseDate.addingTimeInterval(500)) == 597.5)
    }

    @Test("Overtime heartbeat restores overtime paused without offline growth")
    func overtimeHeartbeatRestoresPausedAndExcludesDowntime() throws {
        let fixture = makeController(plannedDuration: 60)
        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(75)
        fixture.ticker.emit(fixture.clock.now)
        let saved = try #require(fixture.persistence.savedSprint)

        let restored = SprintSessionController(
            clock: ManualSprintClock(now: baseDate.addingTimeInterval(600)),
            ticker: ManualSprintTicker(),
            store: fixture.persistence
        )

        #expect(saved.phase == .overtimePaused)
        #expect(restored.lifecycleState == .overtimePaused)
        #expect(restored.elapsedTime == 75)
        #expect(restored.overtimeDuration == 15)
        #expect(!restored.isTickerRunning)
    }

    @Test("Legacy running data restores paused without counting an unknown gap")
    func legacyRunningDataRestoresAtSafeBoundary() throws {
        let persistence = InMemorySprintStore()
        let running = try SprintEngine.start(
            Sprint(taskTitle: "Legacy", plannedDuration: 600),
            at: baseDate
        )
        persistence.save(running)

        let restored = SprintSessionController(
            clock: ManualSprintClock(now: baseDate.addingTimeInterval(90)),
            ticker: ManualSprintTicker(),
            store: persistence
        )

        #expect(restored.lifecycleState == .paused)
        #expect(restored.elapsedTime == 0)
        #expect(restored.remainingTime == 600)
        #expect(!restored.isTickerRunning)
    }

    @Test("Setup and completed sprints are not restored at launch")
    func inactiveSprintsAreNotRestored() {
        let persistence = InMemorySprintStore()
        var completed = Sprint(taskTitle: "Old", plannedDuration: 60)
        completed.phase = .completed
        persistence.save(completed)

        let controller = SprintSessionController(
            clock: ManualSprintClock(now: baseDate),
            ticker: ManualSprintTicker(),
            store: persistence
        )

        #expect(controller.lifecycleState == .setup)
        #expect(persistence.savedSprint == nil)
    }

    @Test("Entering overtime plays the overtime cue exactly once")
    func overtimeCuePlaysOnce() {
        let fixture = makeController(plannedDuration: 60)

        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(61)
        fixture.ticker.emit(fixture.clock.now)
        fixture.clock.now = baseDate.addingTimeInterval(75)
        fixture.ticker.emit(fixture.clock.now)

        #expect(fixture.cues.overtimeCueCount == 1)
        #expect(fixture.cues.finishCueCount == 0)
    }

    @Test("Finishing plays the finish cue")
    func finishCuePlays() {
        let fixture = makeController(plannedDuration: 600)

        fixture.controller.start()
        fixture.clock.now = baseDate.addingTimeInterval(120)
        fixture.ticker.emit(fixture.clock.now)
        fixture.controller.finish()

        #expect(fixture.cues.finishCueCount == 1)
        #expect(fixture.cues.overtimeCueCount == 0)
    }

    @Test("Restoring an overtime sprint does not replay the overtime cue")
    func restoreDoesNotReplayCues() {
        let persistence = InMemorySprintStore()
        let cues = SpyCuePlayer()
        let clock = ManualSprintClock(now: baseDate)
        var overtime = Sprint(taskTitle: "Long haul", plannedDuration: 60)
        overtime.phase = .overtimeRunning
        overtime.originalStartedAt = baseDate.addingTimeInterval(-120)
        overtime.activeSegmentStartedAt = baseDate.addingTimeInterval(-120)
        persistence.save(overtime)

        let controller = SprintSessionController(
            clock: clock,
            ticker: ManualSprintTicker(),
            store: persistence,
            cuePlayer: cues
        )

        #expect(controller.lifecycleState == .overtimePaused)
        #expect(controller.elapsedTime == 60)
        #expect(cues.overtimeCueCount == 0)
    }

    @Test("UserDefaults store round-trips a sprint")
    func userDefaultsStoreRoundTrips() throws {
        let suiteName = "OneClockTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSprintStore(defaults: defaults)

        var sprint = Sprint(taskTitle: "Round trip", plannedDuration: 300)
        sprint.phase = .running
        sprint.originalStartedAt = baseDate
        sprint.activeSegmentStartedAt = baseDate

        store.save(sprint)
        #expect(store.load() == sprint)

        store.save(nil)
        #expect(store.load() == nil)
    }

    private func makeController(plannedDuration: TimeInterval) -> PersistenceFixture {
        let clock = ManualSprintClock(now: baseDate)
        let ticker = ManualSprintTicker()
        let persistence = InMemorySprintStore()
        let cues = SpyCuePlayer()
        let controller = SprintSessionController(
            taskTitle: "Ship runtime",
            plannedDuration: plannedDuration,
            clock: clock,
            ticker: ticker,
            store: persistence,
            cuePlayer: cues
        )

        return PersistenceFixture(
            clock: clock,
            ticker: ticker,
            persistence: persistence,
            cues: cues,
            controller: controller
        )
    }
}

@MainActor
private struct PersistenceFixture {
    let clock: ManualSprintClock
    let ticker: ManualSprintTicker
    let persistence: InMemorySprintStore
    let cues: SpyCuePlayer
    let controller: SprintSessionController
}

private final class InMemorySprintStore: SprintStoring {
    private(set) var savedSprint: Sprint?
    private(set) var saveCallCount = 0

    func load() -> Sprint? {
        savedSprint
    }

    func save(_ sprint: Sprint?) {
        saveCallCount += 1
        savedSprint = sprint
    }
}

@MainActor
private final class SpyCuePlayer: SprintCuePlaying {
    private(set) var overtimeCueCount = 0
    private(set) var finishCueCount = 0

    func playOvertimeCue() {
        overtimeCueCount += 1
    }

    func playFinishCue() {
        finishCueCount += 1
    }
}
