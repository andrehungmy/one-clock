import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var isPanelVisible = false
    let sprintSession: SprintSessionController

    @ObservationIgnored private let panelController: any FloatingPanelControlling

    init(
        sprintSession: SprintSessionController = SprintSessionController(
            store: UserDefaultsSprintStore(),
            cuePlayer: SystemSprintCuePlayer(),
            notifier: UserNotificationSprintNotifier(),
            logStore: UserDefaultsSprintLogStore()
        ),
        panelController: any FloatingPanelControlling = FloatingPanelController()
    ) {
        self.sprintSession = sprintSession
        self.panelController = panelController
        panelController.visibilityDidChange = { [weak self] isVisible in
            self?.isPanelVisible = isVisible
        }

        let isFirstLaunch = !UserDefaults.standard.bool(forKey: FloatingPanelView.hasSeenTutorialDefaultsKey)
        if sprintSession.lifecycleState != .setup || isFirstLaunch {
            // A restored sprint should be visible immediately, and on first
            // launch the panel opens so the tutorial can introduce the app.
            // Defer until the app finishes launching.
            Task { @MainActor [weak self] in
                self?.showPanel()
            }
        }
    }

    func showPanel() {
        panelController.show(session: sprintSession)
        isPanelVisible = panelController.isPanelVisible
    }

    func hidePanel() {
        panelController.hide()
        isPanelVisible = panelController.isPanelVisible
    }

    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
}
