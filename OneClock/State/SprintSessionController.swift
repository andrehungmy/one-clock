import Foundation
import Observation

protocol SprintClock {
    var now: Date { get }
}

struct SystemSprintClock: SprintClock {
    var now: Date {
        Date()
    }
}

@MainActor
protocol SprintTicking: AnyObject {
    var isTicking: Bool { get }

    func start(_ onTick: @escaping @MainActor (Date) -> Void)
    func stop()
}

@MainActor
final class TimerSprintTicker: SprintTicking {
    private let clock: SprintClock
    private let interval: TimeInterval
    private var timer: Timer?

    var isTicking: Bool {
        timer != nil
    }

    init(clock: SprintClock = SystemSprintClock(), interval: TimeInterval = 1) {
        self.clock = clock
        self.interval = interval
    }

    func start(_ onTick: @escaping @MainActor (Date) -> Void) {
        guard timer == nil else {
            return
        }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // The timer is scheduled on the main run loop, so this callback is
            // already on the main thread; assumeIsolated avoids allocating a
            // Task per tick.
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                onTick(self.clock.now)
            }
        }
        // .common keeps the countdown updating while the user drags the panel
        // or tracks a menu; tolerance lets the system coalesce wakeups.
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
protocol SprintCuePlaying: AnyObject {
    func playOvertimeCue()
    func playFinishCue()
}

@MainActor
@Observable
final class SprintSessionController {
    var taskTitle: String
    var plannedDuration: TimeInterval
    private(set) var currentDate: Date
    private(set) var lastError: SprintTransitionError?
    /// Observable mirror of the persisted sprint log, so views (log sidebar,
    /// menu) update the moment a sprint completes or the log is cleared.
    private(set) var logEntries: [SprintLogEntry] = []

    private(set) var sprint: Sprint? {
        didSet {
            guard sprint != oldValue else {
                return
            }
            handleSprintChange(from: oldValue)
        }
    }

    @ObservationIgnored private let clock: SprintClock
    @ObservationIgnored private let ticker: SprintTicking
    @ObservationIgnored private let store: (any SprintStoring)?
    @ObservationIgnored private let cuePlayer: (any SprintCuePlaying)?
    @ObservationIgnored private let notifier: (any SprintNotifying)?
    @ObservationIgnored let logStore: (any SprintLogStoring)?
    @ObservationIgnored private let recoveryHeartbeatInterval: TimeInterval
    @ObservationIgnored private var lastRecoverySnapshotAt: Date?

    init(
        taskTitle: String = "",
        plannedDuration: TimeInterval = Sprint.defaultPlannedDuration,
        clock: SprintClock = SystemSprintClock(),
        ticker: SprintTicking? = nil,
        store: (any SprintStoring)? = nil,
        cuePlayer: (any SprintCuePlaying)? = nil,
        notifier: (any SprintNotifying)? = nil,
        logStore: (any SprintLogStoring)? = nil,
        recoveryHeartbeatInterval: TimeInterval = 5
    ) {
        self.taskTitle = taskTitle
        self.plannedDuration = max(0, min(plannedDuration, Sprint.maximumDisplayedDuration))
        self.clock = clock
        self.currentDate = clock.now
        self.ticker = ticker ?? TimerSprintTicker(clock: clock)
        self.store = store
        self.cuePlayer = cuePlayer
        self.notifier = notifier
        self.logStore = logStore
        self.recoveryHeartbeatInterval = max(0, recoveryHeartbeatInterval)
        self.logEntries = logStore?.entries() ?? []

        restoreFromStoreIfNeeded()
    }

    var lifecycleState: SprintPhase {
        sprint?.phase ?? .setup
    }

    var remainingTime: TimeInterval {
        guard let sprint else {
            return plannedDuration
        }

        return SprintEngine.currentRemainingTime(for: sprint, at: currentDate)
    }

    var elapsedTime: TimeInterval {
        guard let sprint else {
            return 0
        }

        return SprintEngine.focusedElapsedTime(for: sprint, at: currentDate)
    }

    var overtimeDuration: TimeInterval {
        guard let sprint else {
            return 0
        }

        return SprintEngine.overtimeDuration(for: sprint, at: currentDate)
    }

    var isInOvertime: Bool {
        guard let sprint else {
            return false
        }

        return SprintEngine.isInOvertime(sprint, at: currentDate)
    }

    var isTickerRunning: Bool {
        ticker.isTicking
    }

    /// A duration is all that is required; an empty title auto-names itself
    /// ("Sprint N") at start.
    var canStart: Bool {
        lifecycleState == .setup && plannedDuration > 0
    }

    var canPause: Bool {
        lifecycleState == .running || lifecycleState == .overtimeRunning
    }

    var canResume: Bool {
        lifecycleState == .paused || lifecycleState == .overtimePaused
    }

    var canAddFiveMinutes: Bool {
        switch lifecycleState {
        case .running, .paused, .overtimeRunning, .overtimePaused:
            true
        default:
            false
        }
    }

    var canFinish: Bool {
        switch lifecycleState {
        case .running, .paused, .overtimeRunning, .overtimePaused:
            true
        default:
            false
        }
    }

    var canCreateNewSprint: Bool {
        lifecycleState == .completed
    }

    /// Reset is an escape hatch: enabled whenever there is anything to throw
    /// away — an existing sprint or dirty setup fields.
    var canReset: Bool {
        sprint != nil
            || !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || plannedDuration != Sprint.defaultPlannedDuration
    }

    /// Renames the sprint in any phase — setup, running, paused, or completed.
    /// A completed sprint's log entry is kept in sync so the recorded name
    /// matches what the user sees.
    func updateTaskTitle(_ title: String) {
        taskTitle = title
        guard sprint != nil else {
            return
        }

        sprint?.taskTitle = title
        if let sprint, sprint.phase == .completed {
            renameLogEntry(id: sprint.id, to: title)
        }
    }

    func renameLogEntry(id: UUID, to title: String) {
        guard let index = logEntries.firstIndex(where: { $0.id == id }) else {
            return
        }

        let existing = logEntries[index]
        logEntries[index] = SprintLogEntry(
            id: existing.id,
            title: title,
            plannedDuration: existing.plannedDuration,
            investedDuration: existing.investedDuration,
            completedAt: existing.completedAt
        )
        logStore?.overwrite(logEntries)
    }

    func updatePlannedDuration(_ duration: TimeInterval) {
        let clampedDuration = max(0, min(duration, Sprint.maximumDisplayedDuration))
        plannedDuration = clampedDuration
        if sprint?.phase == .setup {
            sprint?.plannedDuration = clampedDuration
            sprint?.initialPlannedDuration = clampedDuration
        }
    }

    func start() {
        guard canStart else {
            record(.invalidTransition(from: lifecycleState, action: .start))
            return
        }

        if taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateTaskTitle(SprintAutoNaming.nextName(after: logEntries))
        }
        notifier?.prepareAuthorization()

        perform(.start) {
            let draft = Sprint(taskTitle: taskTitle, plannedDuration: plannedDuration)
            sprint = try SprintEngine.start(draft, at: currentNow())
            synchronizeDraftFromSprint()
        }
    }

    func pause() {
        guard canPause, let sprint else {
            record(.invalidTransition(from: lifecycleState, action: .pause))
            return
        }

        perform(.pause) {
            self.sprint = try SprintEngine.pause(sprint, at: currentNow())
            synchronizeDraftFromSprint()
        }
    }

    func resume() {
        guard canResume, let sprint else {
            record(.invalidTransition(from: lifecycleState, action: .resume))
            return
        }

        perform(.resume) {
            self.sprint = try SprintEngine.resume(sprint, at: currentNow())
            synchronizeDraftFromSprint()
        }
    }

    func addFiveMinutes() {
        guard canAddFiveMinutes, let sprint else {
            record(.invalidTransition(from: lifecycleState, action: .addFiveMinutes))
            return
        }

        perform(.addFiveMinutes) {
            self.sprint = try SprintEngine.addFiveMinutes(sprint, at: currentNow())
            synchronizeDraftFromSprint()
        }
    }

    func finish() {
        guard canFinish, let sprint else {
            record(.invalidTransition(from: lifecycleState, action: .finish))
            return
        }

        perform(.finish) {
            self.sprint = try SprintEngine.finish(sprint, at: currentNow())
            synchronizeDraftFromSprint()
        }
    }

    func newSprint() {
        guard canCreateNewSprint else {
            return
        }

        sprint = nil
        currentDate = clock.now
        lastError = nil
        coordinateTicker()
    }

    func reset() {
        sprint = nil
        taskTitle = ""
        plannedDuration = Sprint.defaultPlannedDuration
        currentDate = clock.now
        lastError = nil
        coordinateTicker()
    }

    func restore(_ restoredSprint: Sprint, at date: Date? = nil) {
        sprint = restoredSprint
        taskTitle = restoredSprint.taskTitle
        plannedDuration = restoredSprint.plannedDuration
        currentDate = date ?? clock.now
        lastError = nil
        advanceActiveSprintIfNeeded()
        coordinateTicker()
    }

    func tick(at date: Date) {
        currentDate = date
        advanceActiveSprintIfNeeded()
        coordinateTicker()
        persistRecoverySnapshot(force: false)
    }

    /// Saves an exact recovery checkpoint before a normal app termination.
    /// The runtime state stays unchanged because the process is about to exit.
    func prepareForTermination() {
        currentDate = clock.now
        persistRecoverySnapshot(force: true)
    }

    private func perform(_ action: SprintAction, _ operation: () throws -> Void) {
        do {
            currentDate = clock.now
            try operation()
            lastError = nil
            advanceActiveSprintIfNeeded()
            coordinateTicker()
        } catch let error as SprintTransitionError {
            record(error)
        } catch {
            record(.invalidTransition(from: lifecycleState, action: action))
        }
    }

    private func currentNow() -> Date {
        currentDate
    }

    private func record(_ error: SprintTransitionError) {
        lastError = error
        coordinateTicker()
    }

    private func synchronizeDraftFromSprint() {
        guard let sprint else {
            return
        }

        // Only write when values differ: @Observable publishes on every set,
        // and this runs once per tick.
        if taskTitle != sprint.taskTitle {
            taskTitle = sprint.taskTitle
        }
        if plannedDuration != sprint.plannedDuration {
            plannedDuration = sprint.plannedDuration
        }
    }

    private func advanceActiveSprintIfNeeded() {
        guard let sprint else {
            return
        }

        do {
            let advanced = try SprintEngine.advanced(sprint, to: currentDate)
            // Assign only on real change: @Observable notifies on every set,
            // and this runs once per tick.
            if advanced != sprint {
                self.sprint = advanced
            }
            synchronizeDraftFromSprint()
        } catch let error as SprintTransitionError {
            record(error)
        } catch {
            record(.invalidTransition(from: sprint.phase, action: .start))
        }
    }

    private func restoreFromStoreIfNeeded() {
        guard let saved = store?.load() else {
            return
        }

        switch saved.phase {
        case .paused, .overtimePaused:
            var recovered = saved
            recovered.pauseStartedAt = currentDate
            restore(recovered)
        case .running, .overtimeRunning:
            // Legacy versions persisted live running timestamps without a
            // heartbeat date. Recover at the segment start so offline time is
            // never mistaken for focused time.
            let safeCheckpoint = saved.activeSegmentStartedAt
                ?? saved.originalStartedAt
                ?? currentDate
            guard var recovered = try? SprintEngine.recoverySnapshot(saved, at: safeCheckpoint) else {
                store?.save(nil)
                return
            }
            if saved.phase == .overtimeRunning {
                recovered.accumulatedFocusedDuration = max(
                    recovered.accumulatedFocusedDuration,
                    saved.plannedDuration
                )
            }
            recovered.pauseStartedAt = currentDate
            restore(recovered)
        case .setup, .completed:
            store?.save(nil)
        }
    }

    private func handleSprintChange(from oldSprint: Sprint?) {
        persistRecoverySnapshot(force: true)

        guard let sprint, let oldPhase = oldSprint?.phase else {
            return
        }

        let wasInOvertime = oldPhase == .overtimeRunning || oldPhase == .overtimePaused
        let isNowInOvertime = sprint.phase == .overtimeRunning || sprint.phase == .overtimePaused
        if isNowInOvertime, !wasInOvertime {
            cuePlayer?.playOvertimeCue()
            notifier?.notifyTimeUp(taskTitle: sprint.taskTitle)
        }

        if sprint.phase == .completed, oldPhase != .completed {
            cuePlayer?.playFinishCue()
            logCompletion(of: sprint)
        }
    }

    func clearLog() {
        logStore?.clear()
        logEntries = []
    }

    private func logCompletion(of sprint: Sprint) {
        let invested = SprintEngine.actualInvestedTimeAtFinish(for: sprint)
            ?? SprintEngine.focusedElapsedTime(for: sprint, at: currentDate)
        let title = sprint.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = SprintLogEntry(
            id: sprint.id,
            title: title.isEmpty ? "Untitled Sprint" : title,
            plannedDuration: sprint.initialPlannedDuration ?? sprint.plannedDuration,
            investedDuration: invested,
            completedAt: sprint.completedAt ?? currentDate
        )
        logStore?.append(entry)
        logEntries.append(entry)
    }

    private func persistRecoverySnapshot(force: Bool) {
        guard let store else {
            return
        }
        guard let sprint else {
            store.save(nil)
            lastRecoverySnapshotAt = nil
            return
        }

        if !force, let lastRecoverySnapshotAt {
            let timeSinceLastSnapshot = currentDate.timeIntervalSince(lastRecoverySnapshotAt)
            guard timeSinceLastSnapshot < 0
                    || timeSinceLastSnapshot >= recoveryHeartbeatInterval else {
                return
            }
        }

        guard let snapshot = try? SprintEngine.recoverySnapshot(sprint, at: currentDate) else {
            return
        }

        store.save(snapshot)
        lastRecoverySnapshotAt = currentDate
    }

    private func coordinateTicker() {
        switch lifecycleState {
        case .running, .overtimeRunning:
            ticker.start { [weak self] date in
                self?.tick(at: date)
            }
        case .setup, .paused, .overtimePaused, .completed:
            ticker.stop()
        }
    }
}
