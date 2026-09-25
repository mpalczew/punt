import AppKit

class PickerPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func fitToContent() {
        guard let host = contentView else { return }
        host.layoutSubtreeIfNeeded()
        var size = host.fittingSize
        guard size.width > 1, size.height > 1 else { return }
        let bounds = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        size.width = min(max(size.width, 320), min(720, bounds.width - 48))
        size.height = min(max(size.height, 80), bounds.height - 48)
        setContentSize(size)
    }

    func containsMouse(_ point: NSPoint) -> Bool {
        frame.contains(point)
    }
}
