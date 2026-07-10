import AppKit

final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func cancelOperation(_ sender: Any?) {
        // While a text field is being edited, Esc should just end editing —
        // like a normal macOS field — instead of hiding the whole panel.
        if let editor = firstResponder as? NSTextView, editor.isFieldEditor {
            makeFirstResponder(nil)
            return
        }
        onCancel?()
    }
}
