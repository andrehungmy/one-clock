import Foundation

@MainActor
struct SprintMenuCommands: Equatable {
    let canStart: Bool
    let canPause: Bool
    let canResume: Bool
    let canFinish: Bool
    let canCreateNewSprint: Bool
    let canReset: Bool

    init(session: SprintSessionController) {
        canStart = session.canStart
        canPause = session.canPause
        canResume = session.canResume
        canFinish = session.canFinish
        canCreateNewSprint = session.canCreateNewSprint
        canReset = session.canReset
    }
}
