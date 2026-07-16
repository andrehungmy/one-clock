import Foundation
import Testing
@testable import OneClock

@Suite("SprintEngine")
struct SprintEngineTests {
    private let startDate = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test("New Sprint initial state")
    func newSprintInitialState() {
        let sprint = Sprint(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, taskTitle: "Write PRD")

        #expect(sprint.phase == .setup)
        #expect(sprint.taskTitle == "Write PRD")
        #expect(sprint.plannedDuration == 1_500)
        #expect(SprintEngine.focusedElapsedTime(for: sprint, at: startDate) == 0)
    }

    @Test("Start transition")
    func startTransition() throws {
        let sprint = try startedSprint()

        #expect(sprint.phase == .running)
        #expect(sprint.originalStartedAt == startDate)
        #expect(sprint.activeSegmentStartedAt == startDate)
    }

    @Test("Running elapsed time")
    func runningElapsedTime() throws {
        let sprint = try startedSprint()
        let now = startDate.addingTimeInterval(120)

        #expect(SprintEngine.focusedElapsedTime(for: sprint, at: now) == 120)
        #expect(SprintEngine.currentRemainingTime(for: sprint, at: now) == 1_380)
    }

    @Test("Pause freezes focused elapsed time")
    func pauseFreezesFocusedElapsedTime() throws {
        let sprint = try startedSprint()
        let paused = try SprintEngine.pause(sprint, at: startDate.addingTimeInterval(120))
        let later = startDate.addingTimeInterval(420)

        #expect(paused.phase == .paused)
        #expect(SprintEngine.focusedElapsedTime(for: paused, at: later) == 120)
        #expect(SprintEngine.currentRemainingTime(for: paused, at: later) == 1_380)
    }

    @Test("Recovery snapshot pauses a running sprint at the checkpoint")
    func recoverySnapshotPausesRunningSprint() throws {
        let sprint = try startedSprint(plannedDuration: 600)
        let checkpoint = startDate.addingTimeInterval(120)
        let snapshot = try SprintEngine.recoverySnapshot(sprint, at: checkpoint)

        #expect(snapshot.phase == .paused)
        #expect(snapshot.activeSegmentStartedAt == nil)
        #expect(snapshot.pauseStartedAt == checkpoint)
        #expect(SprintEngine.focusedElapsedTime(for: snapshot, at: checkpoint.addingTimeInterval(600)) == 120)
        #expect(SprintEngine.currentRemainingTime(for: snapshot, at: checkpoint.addingTimeInterval(600)) == 480)
    }

    @Test("Recovery snapshot preserves overtime without offline growth")
    func recoverySnapshotPausesOvertimeSprint() throws {
        let sprint = try startedSprint(plannedDuration: 60)
        let checkpoint = startDate.addingTimeInterval(75)
        let snapshot = try SprintEngine.recoverySnapshot(sprint, at: checkpoint)

        #expect(snapshot.phase == .overtimePaused)
        #expect(SprintEngine.focusedElapsedTime(for: snapshot, at: checkpoint.addingTimeInterval(600)) == 75)
        #expect(SprintEngine.overtimeDuration(for: snapshot, at: checkpoint.addingTimeInterval(600)) == 15)
    }

    @Test("Resume starts a new running segment")
    func resumeStartsNewRunningSegment() throws {
        let sprint = try startedSprint()
        let paused = try SprintEngine.pause(sprint, at: startDate.addingTimeInterval(120))
        let resumed = try SprintEngine.resume(paused, at: startDate.addingTimeInterval(300))
        let now = startDate.addingTimeInterval(360)

        #expect(resumed.phase == .running)
        #expect(SprintEngine.focusedElapsedTime(for: resumed, at: now) == 180)
        #expect(resumed.accumulatedPausedDuration == 180)
    }

    @Test("Multiple pause and resume cycles")
    func multiplePauseResumeCycles() throws {
        let firstRun = try startedSprint()
        let firstPause = try SprintEngine.pause(firstRun, at: startDate.addingTimeInterval(100))
        let secondRun = try SprintEngine.resume(firstPause, at: startDate.addingTimeInterval(200))
        let secondPause = try SprintEngine.pause(secondRun, at: startDate.addingTimeInterval(250))
        let thirdRun = try SprintEngine.resume(secondPause, at: startDate.addingTimeInterval(300))

        #expect(SprintEngine.focusedElapsedTime(for: thirdRun, at: startDate.addingTimeInterval(330)) == 180)
        #expect(thirdRun.accumulatedPausedDuration == 150)
    }

    @Test("Add five minutes while running")
    func addFiveMinutesWhileRunning() throws {
        let sprint = try startedSprint(plannedDuration: 600)
        let extended = try SprintEngine.addFiveMinutes(sprint, at: startDate.addingTimeInterval(120))

        #expect(extended.phase == .running)
        #expect(SprintEngine.currentRemainingTime(for: extended, at: startDate.addingTimeInterval(120)) == 780)
        #expect(SprintEngine.totalPlannedDuration(for: extended) == 900)
    }

    @Test("Add five minutes while paused")
    func addFiveMinutesWhilePaused() throws {
        let sprint = try startedSprint(plannedDuration: 600)
        let paused = try SprintEngine.pause(sprint, at: startDate.addingTimeInterval(120))
        let extended = try SprintEngine.addFiveMinutes(paused, at: startDate.addingTimeInterval(300))

        #expect(extended.phase == .paused)
        #expect(SprintEngine.currentRemainingTime(for: extended, at: startDate.addingTimeInterval(900)) == 780)
    }

    @Test("Remaining time reaches zero exactly")
    func remainingTimeReachesZeroExactly() throws {
        let sprint = try startedSprint(plannedDuration: 300)
        let atEnd = startDate.addingTimeInterval(300)
        let advanced = try SprintEngine.advanced(sprint, to: atEnd)

        #expect(SprintEngine.currentRemainingTime(for: advanced, at: atEnd) == 0)
        #expect(advanced.phase == .overtimeRunning)
        #expect(SprintEngine.overtimeDuration(for: advanced, at: atEnd) == 0)
    }

    @Test("Overtime becomes positive after planned end")
    func overtimeBecomesPositiveAfterPlannedEnd() throws {
        let sprint = try startedSprint(plannedDuration: 300)
        let afterEnd = startDate.addingTimeInterval(330)
        let advanced = try SprintEngine.advanced(sprint, to: afterEnd)

        #expect(advanced.phase == .overtimeRunning)
        #expect(SprintEngine.currentRemainingTime(for: advanced, at: afterEnd) == 0)
        #expect(SprintEngine.isInOvertime(advanced, at: afterEnd))
        #expect(SprintEngine.overtimeDuration(for: advanced, at: afterEnd) == 30)
    }

    @Test("Finish while running")
    func finishWhileRunning() throws {
        let sprint = try startedSprint()
        let finished = try SprintEngine.finish(sprint, at: startDate.addingTimeInterval(420))

        #expect(finished.phase == .completed)
        #expect(finished.completedAt == startDate.addingTimeInterval(420))
        #expect(finished.finishOutcome == .completed)
        #expect(SprintEngine.actualInvestedTimeAtFinish(for: finished) == 420)
    }

    @Test("Finish while paused")
    func finishWhilePaused() throws {
        let sprint = try startedSprint()
        let paused = try SprintEngine.pause(sprint, at: startDate.addingTimeInterval(120))
        let finished = try SprintEngine.finish(paused, at: startDate.addingTimeInterval(420))

        #expect(finished.phase == .completed)
        #expect(SprintEngine.actualInvestedTimeAtFinish(for: finished) == 120)
    }

    @Test("Actual invested time excludes paused time")
    func actualInvestedTimeExcludesPausedTime() throws {
        let sprint = try startedSprint()
        let paused = try SprintEngine.pause(sprint, at: startDate.addingTimeInterval(120))
        let resumed = try SprintEngine.resume(paused, at: startDate.addingTimeInterval(420))
        let finished = try SprintEngine.finish(resumed, at: startDate.addingTimeInterval(600))

        #expect(SprintEngine.actualInvestedTimeAtFinish(for: finished) == 300)
        #expect(finished.accumulatedPausedDuration == 300)
    }

    @Test("Invalid double start")
    func invalidDoubleStart() throws {
        let sprint = try startedSprint()

        #expect(throws: SprintTransitionError.invalidTransition(from: .running, action: .start)) {
            try SprintEngine.start(sprint, at: startDate.addingTimeInterval(1))
        }
    }

    @Test("Add five minutes in overtime returns to running with five minutes remaining")
    func addFiveMinutesInOvertime() throws {
        let sprint = try startedSprint(plannedDuration: 300)
        let overtime = try SprintEngine.advanced(sprint, to: startDate.addingTimeInterval(330))
        let extended = try SprintEngine.addFiveMinutes(overtime, at: startDate.addingTimeInterval(330))

        #expect(extended.phase == .running)
        #expect(SprintEngine.currentRemainingTime(for: extended, at: startDate.addingTimeInterval(330)) == 300)
    }

    private func startedSprint(plannedDuration: TimeInterval = 1_500) throws -> Sprint {
        let sprint = Sprint(taskTitle: "Write PRD", plannedDuration: plannedDuration)
        return try SprintEngine.start(sprint, at: startDate)
    }
}
