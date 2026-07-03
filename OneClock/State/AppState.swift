import Observation

@MainActor
@Observable
final class AppState {
    var isPanelVisible = false

    private let panelController = FloatingPanelController()

    init() {
        panelController.visibilityDidChange = { [weak self] isVisible in
            self?.isPanelVisible = isVisible
        }
    }

    func showPanel() {
        panelController.show()
        isPanelVisible = true
    }

    func hidePanel() {
        panelController.hide()
        isPanelVisible = false
    }
}
