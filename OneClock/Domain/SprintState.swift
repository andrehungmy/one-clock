import Foundation

// Sprint itself lives in SprintEngine.swift; shared enums live here.

enum SprintPhase: String, Codable, Equatable {
    case setup
    case running
    case paused
    case overtimeRunning
    case overtimePaused
    case completed
}

enum SprintFinishOutcome: String, Codable, Equatable {
    case completed
}

enum SprintTransitionError: Error, Equatable {
    case invalidTransition(from: SprintPhase, action: SprintAction)
    case invalidDuration
    case dateBeforeReferenceDate
}

enum SprintAction: String, Equatable {
    case start
    case pause
    case resume
    case addFiveMinutes
    case finish
}

