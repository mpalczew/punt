import AppKit

class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    var onSetDefault: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var onReopenURL: ((URL) -> Void)?
    var urlHistoryProvider: (() -> [PickerState.URLHistoryEntry])?

    var statusItemFrame: NSRect {
        statusItem?.button?.window?.frame ?? .zero
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = makeMenuBarIcon()
        button.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let history = urlHistoryProvider?() ?? []
        if !history.isEmpty {
            let header = NSMenuItem(title: "Recent URLs", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for entry in history {
                let displayTitle = truncatedURL(entry.urlString, maxLength: 60)
                let item = NSMenuItem(title: displayTitle, action: #selector(reopenURLAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = URL(string: entry.urlString)
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
        }

        let setDefault = NSMenuItem(title: "Set as Default Browser", action: #selector(setDefaultAction), keyEquivalent: "")
        setDefault.target = self
        menu.addItem(setDefault)

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit Punt", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func reopenURLAction(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onReopenURL?(url)
    }

    @objc private func setDefaultAction() {
        onSetDefault?()
    }

    @objc private func settingsAction() {
        onShowSettings?()
    }

    @objc private func quitAction() {
        onQuit?()
    }

    // MARK: - Private

    private func truncatedURL(_ urlString: String, maxLength: Int) -> String {
        guard urlString.count > maxLength else { return urlString }
        return "…" + urlString.suffix(maxLength - 1)
    }

    /// Draws a small routing/punt icon: a dot on the left with three arrows fanning right
    private func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let color = NSColor.black

            // Origin dot
            let dotRect = NSRect(x: 1, y: 7, width: 4, height: 4)
            let dot = NSBezierPath(ovalIn: dotRect)
            color.setFill()
            dot.fill()

            // Three fanning lines from dot to right
            let path = NSBezierPath()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            color.setStroke()

            // Top line
            path.move(to: NSPoint(x: 5, y: 10))
            path.line(to: NSPoint(x: 14, y: 15))
            // Middle line
            path.move(to: NSPoint(x: 5, y: 9))
            path.line(to: NSPoint(x: 15, y: 9))
            // Bottom line
            path.move(to: NSPoint(x: 5, y: 8))
            path.line(to: NSPoint(x: 14, y: 3))
            path.stroke()

            // Arrowheads
            let arrows = NSBezierPath()
            arrows.lineWidth = 1.2
            arrows.lineCapStyle = .round
            arrows.lineJoinStyle = .round
            color.setStroke()

            // Top arrow
            arrows.move(to: NSPoint(x: 11, y: 16))
            arrows.line(to: NSPoint(x: 14, y: 15))
            arrows.line(to: NSPoint(x: 12, y: 12.5))
            // Middle arrow
            arrows.move(to: NSPoint(x: 12.5, y: 12))
            arrows.line(to: NSPoint(x: 15, y: 9))
            arrows.line(to: NSPoint(x: 12.5, y: 6))
            // Bottom arrow
            arrows.move(to: NSPoint(x: 11, y: 2))
            arrows.line(to: NSPoint(x: 14, y: 3))
            arrows.line(to: NSPoint(x: 12, y: 5.5))
            arrows.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
