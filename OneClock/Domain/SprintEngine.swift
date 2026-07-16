import Foundation

struct Sprint: Codable, Equatable, Identifiable {
    static let defaultPlannedDuration: TimeInterval = 25 * 60
    static let maximumDisplayedDuration: TimeInterval = (99 * 60) + 59
    static let fiveMinutes: TimeInterval = 5 * 60

    let id: UUID
    var taskTitle: String
    var plannedDuration: TimeInterval
    /// The duration the user originally entered, unaffected by later "+5m"
    /// extensions. Optional so sprints persisted before this field decode.
    var initialPlannedDuration: TimeInterval?
    var phase: SprintPhase
    var originalStartedAt: Date?
    var activeSegmentStartedAt: Date?
    var accumulatedFocusedDuration: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
    var completedAt: Date?
    var finishOutcome: SprintFinishOutcome?

    init(
        id: UUID = UUID(),
        taskTitle: String,
        plannedDuration: TimeInterval = Sprint.defaultPlannedDuration
    ) {
        self.id = id
        self.taskTitle = taskTitle
        self.plannedDuration = max(0, min(plannedDuration, Sprint.maximumDisplayedDuration))
        self.initialPlannedDuration = self.plannedDuration
        self.phase = .setup
        self.originalStartedAt = nil
        self.activeSegmentStartedAt = nil
        self.accumulatedFocusedDuration = 0
        self.accumulatedPausedDuration = 0
        self.pauseStartedAt = nil
        self.completedAt = nil
        self.finishOutcome = nil
    }
}

enum SprintEngine {
    static func start(_ sprint: Sprint, at date: Date) throws -> Sprint {
        guard sprint.phase == .setup else {
            throw SprintTransitionError.invalidTransition(from: sprint.phase, action: .start)
        }
        guard sprint.plannedDuration > 0 else {
            throw SprintTransitionError.invalidDuration
        }

        var updated = sprint
        updated.phase = .running
        updated.originalStartedAt = date
        updated.activeSegmentStartedAt = date
        return updated
    }

    static func pause(_ sprint: Sprint, at date: Date) throws -> Sprint {
        var updated = try advanced(sprint, to: date)

        switch updated.phase {
        case .running, .overtimeRunning:
            if let segmentStart = updated.activeSegmentStartedAt {
                guard date >= segmentStart else {
                    throw SprintTransitionError.dateBeforeReferenceDate
                }
                updated.accumulatedFocusedDuration += date.timeIntervalSince(segmentStart)
            }
            updated.activeSegmentStartedAt = nil
            updated.pauseStartedAt = date
            updated.phase = updated.phase == .overtimeRunning ? .overtimePaused : .paused
            return updated
        default:
            throw SprintTransitionError.invalidTransition(from: updated.phase, action: .pause)
        }
    }

    /// Produces the persisted form of an active sprint without changing the
    /// in-memory runtime state. Running phases become paused at the snapshot
    /// date so time after the checkpoint is never counted during recovery.
    static func recoverySnapshot(_ sprint: Sprint, at date: Date) throws -> Sprint {
        switch sprint.phase {
        case .running, .overtimeRunning:
            try pause(sprint, at: date)
        case .setup, .paused, .overtimePaused, .completed:
            sprint
        }
    }

    static func resume(_ sprint: Sprint, at date: Date) throws -> Sprint {
        var updated = try advanced(sprint, to: date)

        switch updated.phase {
        case .paused, .overtimePaused:
            if let pauseStartedAt = updated.pauseStartedAt {
                guard date >= pauseStartedAt else {
                    throw SprintTransitionError.dateBeforeReferenceDate
                }
                updated.accumulatedPausedDuration += date.timeIntervalSince(pauseStartedAt)
            }
            updated.pauseStartedAt = nil
            updated.activeSegmentStartedAt = date
            updated.phase = updated.phase == .overtimePaused ? .overtimeRunning : .running
            return updated
        default:
            throw SprintTransitionError.invalidTransition(from: updated.phase, action: .resume)
        }
    }

    static func addFiveMinutes(_ sprint: Sprint, at date: Date) throws -> Sprint {
        var updated = try advanced(sprint, to: date)

        switch updated.phase {
        case .running, .paused:
            let focusedElapsed = focusedElapsedTime(for: updated, at: date)
            let remaining = remainingTime(for: updated, at: date)
            let adjustedRemaining = min(remaining + Sprint.fiveMinutes, Sprint.maximumDisplayedDuration)
            updated.plannedDuration = focusedElapsed + adjustedRemaining
            return updated
        case .overtimeRunning:
            let focusedElapsed = focusedElapsedTime(for: updated, at: date)
            updated.plannedDuration = focusedElapsed + Sprint.fiveMinutes
            updated.phase = .running
            return updated
        case .overtimePaused:
            let focusedElapsed = focusedElapsedTime(for: updated, at: date)
            updated.plannedDuration = focusedElapsed + Sprint.fiveMinutes
            updated.phase = .paused
            return updated
        default:
            throw SprintTransitionError.invalidTransition(from: updated.phase, action: .addFiveMinutes)
        }
    }

    static func finish(_ sprint: Sprint, at date: Date) throws -> Sprint {
        var updated = try advanced(sprint, to: date)

        switch updated.phase {
        case .running, .overtimeRunning:
            if let segmentStart = updated.activeSegmentStartedAt {
                guard date >= segmentStart else {
                    throw SprintTransitionError.dateBeforeReferenceDate
                }
                updated.accumulatedFocusedDuration += date.timeIntervalSince(segmentStart)
            }
            updated.activeSegmentStartedAt = nil
        case .paused, .overtimePaused:
            if let pauseStartedAt = updated.pauseStartedAt {
                guard date >= pauseStartedAt else {
                    throw SprintTransitionError.dateBeforeReferenceDate
                }
                updated.accumulatedPausedDuration += date.timeIntervalSince(pauseStartedAt)
            }
            updated.pauseStartedAt = nil
        default:
            throw SprintTransitionError.invalidTransition(from: updated.phase, action: .finish)
        }

        updated.phase = .completed
        updated.completedAt = date
        updated.finishOutcome = .completed
        return updated
    }

    static func advanced(_ sprint: Sprint, to date: Date) throws -> Sprint {
        var updated = sprint

        switch sprint.phase {
        case .running:
            guard let segmentStart = sprint.activeSegmentStartedAt else {
                return updated
            }
            guard date >= segmentStart else {
                throw SprintTransitionError.dateBeforeReferenceDate
            }
            let focusedElapsed = focusedElapsedTime(for: sprint, at: date)
            if focusedElapsed >= sprint.plannedDuration {
                updated.phase = .overtimeRunning
            }
        case .paused:
            if let pauseStartedAt = sprint.pauseStartedAt, date < pauseStartedAt {
                throw SprintTransitionError.dateBeforeReferenceDate
            }
            if sprint.accumulatedFocusedDuration >= sprint.plannedDuration {
                updated.phase = .overtimePaused
            }
        case .overtimeRunning:
            if let segmentStart = sprint.activeSegmentStartedAt, date < segmentStart {
                throw SprintTransitionError.dateBeforeReferenceDate
            }
        case .overtimePaused:
            if let pauseStartedAt = sprint.pauseStartedAt, date < pauseStartedAt {
                throw SprintTransitionError.dateBeforeReferenceDate
            }
        case .setup, .completed:
            break
        }

        return updated
    }

    static func focusedElapsedTime(for sprint: Sprint, at date: Date) -> TimeInterval {
        guard sprint.phase != .setup else {
            return 0
        }

        var elapsed = sprint.accumulatedFocusedDuration
        if let segmentStart = sprint.activeSegmentStartedAt,
           sprint.phase == .running || sprint.phase == .overtimeRunning {
            elapsed += max(0, date.timeIntervalSince(segmentStart))
        }
        return elapsed
    }

    static func currentRemainingTime(for sprint: Sprint, at date: Date) -> TimeInterval {
        remainingTime(for: sprint, at: date)
    }

    static func isInOvertime(_ sprint: Sprint, at date: Date) -> Bool {
        overtimeDuration(for: sprint, at: date) > 0
    }

    static func overtimeDuration(for sprint: Sprint, at date: Date) -> TimeInterval {
        max(0, focusedElapsedTime(for: sprint, at: date) - sprint.plannedDuration)
    }

    static func totalPlannedDuration(for sprint: Sprint) -> TimeInterval {
        sprint.plannedDuration
    }

    static func actualInvestedTimeAtFinish(for sprint: Sprint) -> TimeInterval? {
        guard sprint.phase == .completed, let completedAt = sprint.completedAt else {
            return nil
        }
        return focusedElapsedTime(for: sprint, at: completedAt)
    }

    private static func remainingTime(for sprint: Sprint, at date: Date) -> TimeInterval {
        max(0, sprint.plannedDuration - focusedElapsedTime(for: sprint, at: date))
    }
}
