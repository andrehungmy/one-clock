import AppKit
import SwiftUI

@MainActor
protocol FloatingPanelControlling: AnyObject {
    var visibilityDidChange: ((Bool) -> Void)? { get set }
    var isPanelVisible: Bool { get }

    func show(session: SprintSessionController)
    func hide()
}

private enum PanelWindowSize {
    static let initial = NSSize(width: 320, height: 236)
    static let minimum = NSSize(width: 260, height: 212)
    static let maximum = NSSize(width: 800, height: 560)
    static let compact = NSSize(width: 264, height: 60)
}

@MainActor
final class FloatingPanelController: NSObject, FloatingPanelControlling, NSWindowDelegate {
    var visibilityDidChange: ((Bool) -> Void)?
    private(set) var createdPanelCount = 0

    private var panel: FloatingPanel?
    private var expandedFrame: NSRect?

    var isPanelVisible: Bool {
        panel?.isVisible ?? false
    }

    func show(session: SprintSessionController) {
        let panel = existingOrCreatePanel(session: session)
        // Already showing on another desktop: order it out first so it re-homes
        // to the desktop the user is on now, instead of switching desktops.
        if panel.isVisible, !panel.isOnActiveSpace {
            panel.orderOut(nil)
        }
        panel.centerOnVisibleScreenIfNeeded()
        panel.orderFrontRegardless()
        panel.makeKey()
        visibilityDidChange?(panel.isVisible)
    }

    func hide() {
        panel?.orderOut(nil)
        visibilityDidChange?(isPanelVisible)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    func windowWillClose(_ notification: Notification) {
        visibilityDidChange?(isPanelVisible)
    }

    /// Switches the window between the full panel and the compact pill.
    /// Anchored to the top-left corner so the panel does not appear to move.
    func resizePanel(compact: Bool) {
        guard let panel else {
            return
        }

        if compact {
            if panel.frame.height > PanelWindowSize.compact.height {
                expandedFrame = panel.frame
            }
            panel.contentMinSize = PanelWindowSize.compact
            panel.contentMaxSize = PanelWindowSize.compact
            setFrameSize(PanelWindowSize.compact, for: panel)
        } else {
            panel.contentMinSize = PanelWindowSize.minimum
            panel.contentMaxSize = PanelWindowSize.maximum
            var target = expandedFrame?.size ?? PanelWindowSize.initial
            let current = panel.frame.size
            if current.width >= PanelWindowSize.minimum.width,
               current.height >= PanelWindowSize.minimum.height {
                target = current
            }
            setFrameSize(target, for: panel)
        }
    }

    private func setFrameSize(_ size: NSSize, for panel: NSPanel) {
        let frame = PanelLayout.topAnchoredFrame(from: panel.frame, size: size)
        panel.setFrame(frame, display: true, animate: true)
    }

    private func existingOrCreatePanel(session: SprintSessionController) -> FloatingPanel {
        if let panel {
            return panel
        }

        let hostingController = NSHostingController(rootView: FloatingPanelView(
            session: session,
            onClose: { [weak self] in
                self?.hide()
            },
            onCompactChange: { [weak self] compact in
                self?.resizePanel(compact: compact)
            }
        ))
        hostingController.sizingOptions = [.minSize]
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: PanelWindowSize.initial),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.contentMinSize = PanelWindowSize.minimum
        panel.contentMaxSize = PanelWindowSize.maximum
        panel.onCancel = { [weak self] in
            self?.hide()
        }
        panel.setFrameAutosaveName("OneClockFloatingPanel")
        panel.delegate = self
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        // Behave like a normal macOS window instead of tiling across every
        // Space: `.moveToActiveSpace` binds the panel to a single Space — it
        // stays behind when you switch desktops and is summoned to the current
        // desktop when reopened — and can be dragged to another desktop.
        // `.fullScreenAuxiliary` keeps it available over full-screen apps.
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        self.panel = panel
        createdPanelCount += 1
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
