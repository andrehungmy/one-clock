import Foundation
import Testing
@testable import OneClock

@Suite("Single Instance Policy")
struct SingleInstancePolicyTests {
    @Test("The oldest launch remains the primary app instance")
    func oldestLaunchWins() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let instances = [
            AppInstanceIdentity(processIdentifier: 300, launchDate: now),
            AppInstanceIdentity(processIdentifier: 200, launchDate: now.addingTimeInterval(-1)),
        ]

        #expect(SingleInstancePolicy.primaryProcessIdentifier(in: instances) == 200)
    }

    @Test("Process identifier provides a deterministic tie-breaker")
    func processIdentifierBreaksTies() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let instances = [
            AppInstanceIdentity(processIdentifier: 300, launchDate: now),
            AppInstanceIdentity(processIdentifier: 200, launchDate: now),
        ]

        #expect(SingleInstancePolicy.primaryProcessIdentifier(in: instances) == 200)
    }

    @Test("A launch date takes priority over a missing launch date")
    func knownLaunchDateWins() {
        let instances = [
            AppInstanceIdentity(processIdentifier: 100, launchDate: nil),
            AppInstanceIdentity(
                processIdentifier: 200,
                launchDate: Date(timeIntervalSinceReferenceDate: 10_000)
            ),
        ]

        #expect(SingleInstancePolicy.primaryProcessIdentifier(in: instances) == 200)
    }
}

@MainActor
@Suite("Menu and Panel Lifecycle")
struct MenuAndPanelLifecycleTests {
    private let baseDate = Date(timeIntervalSinceReferenceDate: 8_000)

    @Test("Repeated show calls reuse the same floating panel")
    func repeatedShowCallsReuseSamePanel() {
        let controller = FloatingPanelController()
        let session = SprintSessionController(taskTitle: "Plan launch")

        controller.show(session: session)
        controller.show(session: session)
        controller.show(session: session)

        #expect(controller.createdPanelCount == 1)
        #expect(controller.isPanelVisible)

        controller.hide()
    }

    @Test("Hide and show do not destroy or reset the sprint session")
    func hideAndShowPreserveSprintSession() {
        let fixture = makeAppState()

        fixture.session.updateTaskTitle("Draft launch note")
        fixture.session.start()
        fixture.appState.showPanel()
        fixture.appState.hidePanel()
        fixture.appState.showPanel()

        #expect(fixture.appState.isPanelVisible)
        #expect(fixture.session.lifecycleState == .running)
        #expect(fixture.session.taskTitle == "Draft launch note")
        #expect(fixture.session.remainingTime == 600)
        #expect(fixture.panelController.showCallCount == 2)
        #expect(fixture.panelController.hideCallCount == 1)
    }

    @Test("Toggling the panel flips visibility so the menu label follows")
    func togglePanelFlipsVisibility() {
        let fixture = makeAppState()

        #expect(!fixture.appState.isPanelVisible)

        fixture.appState.togglePanel()
        #expect(fixture.appState.isPanelVisible)

        // Hiding must flip the toggle back so the menu reads "Show One Clock".
        fixture.appState.togglePanel()
        #expect(!fixture.appState.isPanelVisible)
    }

    @Test("Running sprint continues ticking while panel is hidden")
    func runningSprintContinuesWhileHidden() {
        let fixture = makeAppState()

        fixture.session.updateTaskTitle("Focus")
        fixture.session.start()
        fixture.appState.showPanel()
        fixture.appState.hidePanel()
        fixture.clock.now = baseDate.addingTimeInterval(90)
        fixture.ticker.emit(fixture.clock.now)

        #expect(!fixture.appState.isPanelVisible)
        #expect(fixture.session.lifecycleState == .running)
        #expect(fixture.session.elapsedTime == 90)
        #expect(fixture.session.remainingTime == 510)
    }

    @Test("Menu command availability follows controller capabilities")
    func menuCommandAvailability() {
        let fixture = makeAppState()

        var commands = SprintMenuCommands(session: fixture.session)
        // A duration alone is enough to start — untitled sprints auto-name.
        #expect(commands.canStart)
        #expect(!commands.canPause)
        #expect(!commands.canResume)
        #expect(!commands.canFinish)
        #expect(!commands.canCreateNewSprint)
        #expect(commands.canReset)

        fixture.session.updateTaskTitle("Review")
        commands = SprintMenuCommands(session: fixture.session)
        #expect(commands.canStart)

        fixture.session.start()
        commands = SprintMenuCommands(session: fixture.session)
        #expect(commands.canPause)
        #expect(commands.canFinish)
        #expect(!commands.canResume)

        fixture.session.pause()
        commands = SprintMenuCommands(session: fixture.session)
        #expect(commands.canResume)
        #expect(commands.canFinish)
        #expect(!commands.canPause)

        fixture.session.finish()
        commands = SprintMenuCommands(session: fixture.session)
        #expect(commands.canCreateNewSprint)
        #expect(!commands.canFinish)
    }

    private func makeAppState() -> AppFixture {
        let clock = ManualSprintClock(now: baseDate)
        let ticker = ManualSprintTicker()
        let session = SprintSessionController(
            taskTitle: "",
            plannedDuration: 600,
            clock: clock,
            ticker: ticker
        )
        let panelController = FakePanelController()
        let appState = AppState(sprintSession: session, panelController: panelController)
        return AppFixture(
            appState: appState,
            session: session,
            clock: clock,
            ticker: ticker,
            panelController: panelController
        )
    }
}

@MainActor
private struct AppFixture {
    let appState: AppState
    let session: SprintSessionController
    let clock: ManualSprintClock
    let ticker: ManualSprintTicker
    let panelController: FakePanelController
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
    private(set) var isTicking = false

    func start(_ onTick: @escaping @MainActor (Date) -> Void) {
        guard !isTicking else {
            return
        }

        self.onTick = onTick
        isTicking = true
    }

    func stop() {
        guard isTicking else {
            return
        }

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
private final class FakePanelController: FloatingPanelControlling {
    var visibilityDidChange: ((Bool) -> Void)?
    private(set) var isPanelVisible = false
    private(set) var showCallCount = 0
    private(set) var hideCallCount = 0
    private(set) var lastSession: SprintSessionController?

    func show(session: SprintSessionController) {
        showCallCount += 1
        lastSession = session
        isPanelVisible = true
        visibilityDidChange?(true)
    }

    func hide() {
        hideCallCount += 1
        isPanelVisible = false
        visibilityDidChange?(false)
    }
}
