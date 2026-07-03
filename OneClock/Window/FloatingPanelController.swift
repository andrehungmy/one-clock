import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    var visibilityDidChange: ((Bool) -> Void)?

    private var panel: FloatingPanel?

    func show() {
        let panel = existingOrCreatePanel()
        panel.centerOnVisibleScreenIfNeeded()
        panel.orderFrontRegardless()
        visibilityDidChange?(true)
    }

    func hide() {
        panel?.orderOut(nil)
        visibilityDidChange?(false)
    }

    func windowWillClose(_ notification: Notification) {
        visibilityDidChange?(false)
    }

    private func existingOrCreatePanel() -> FloatingPanel {
        if let panel {
            return panel
        }

        let hostingController = NSHostingController(rootView: FloatingPanelView { [weak self] in
            self?.hide()
        })
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.delegate = self
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.panel = panel
        return panel
    }
}

private extension NSWindow {
    func centerOnVisibleScreenIfNeeded() {
        guard let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            center()
            return
        }

        if visibleFrame.intersects(frame) {
            return
        }

        setFrameOrigin(NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.midY - frame.height / 2
        ))
    }
}
