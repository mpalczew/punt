import AppKit
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let instanceCoordinator = SingleInstanceCoordinator()
    private var panel: PickerPanel!
    private var pickerState: PickerState!
    private var menuBarManager: MenuBarManager!
    private var settingsWindow: NSWindow?
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private let autoUpdater = AutoUpdater()
    private var urlLaunched = false
    /// Document/URL opens can arrive before didFinishLaunching finishes wiring UI.
    private var isReady = false
    private var pendingURLs: [URL] = []
    private var isPrimaryInstance = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        switch instanceCoordinator.claim() {
        case .acquired:
            isPrimaryInstance = true
            instanceCoordinator.onForwardedURL = { [weak self] url in
                self?.receive(url)
            }
        case .alreadyRunning:
            NSLog("Punt: another instance is already running")
        case .unavailable(let error):
            NSLog("Punt: unable to claim single-instance lock: \(error)")
            isPrimaryInstance = true
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isPrimaryInstance else {
            instanceCoordinator.forward(urls: pendingURLs)
            NSApp.terminate(nil)
            return
        }

        pickerState = PickerState()
        pickerState.loadBrowsers()

        let panelRect = NSRect(x: 0, y: 0, width: 600, height: 200)
        panel = PickerPanel(contentRect: panelRect)

        let pickerView = PickerView(
            state: pickerState,
            onSelect: { [weak self] browser, profile in self?.launchURL(in: browser, profile: profile) },
            onDismiss: { [weak self] in self?.hidePanel() },
            onLayoutChange: { [weak self] in self?.fitPicker() },
            onRequestAccess: { [weak self] in self?.promptForFullDiskAccess() }
        )
        panel.contentView = NSHostingView(rootView: pickerView)

        menuBarManager = MenuBarManager()
        menuBarManager.onSetDefault = { [weak self] in self?.promptSetDefaultBrowser() }
        menuBarManager.onShowSettings = { [weak self] in self?.showSettings() }
        menuBarManager.onQuit = { NSApp.terminate(nil) }
        menuBarManager.onReopenURL = { [weak self] url in self?.showPicker(for: url) }
        menuBarManager.urlHistoryProvider = { [weak self] in self?.pickerState.urlHistory() ?? [] }
        menuBarManager.setup()

        registerLocalMonitor()
        registerClickOutsideMonitor()

        autoUpdater.isPanelHidden = { [weak self] in !(self?.panel.isVisible ?? false) }
        if HomebrewDetector.isInstalledApplication {
            autoUpdater.startMonitoring()
        } else {
            NSLog("Punt: auto-update disabled for development build")
        }

        isReady = true
        let queued = pendingURLs
        pendingURLs.removeAll()
        for url in queued {
            receive(url)
        }

        if HomebrewDetector.isInstalledApplication {
            enableLoginItem()
        }

        if !UserDefaults.standard.bool(forKey: "punt_has_launched") {
            UserDefaults.standard.set(true, forKey: "punt_has_launched")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.promptSetDefaultBrowser()
            }
        }
    }

    // MARK: - URL Handling

    func application(_ sender: NSApplication, open urls: [URL]) {
        guard isPrimaryInstance else {
            instanceCoordinator.forward(urls: urls)
            NSApp.terminate(nil)
            return
        }
        for url in urls {
            receive(url)
        }
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }

        guard isPrimaryInstance else {
            instanceCoordinator.forward(urls: [url])
            NSApp.terminate(nil)
            return
        }
        receive(url)
    }

    private func receive(_ url: URL) {
        if !isReady {
            pendingURLs.append(url)
            return
        }

        let cleanedURL: URL
        if url.isFileURL {
            cleanedURL = url
        } else if UserDefaults.standard.bool(forKey: "punt_strip_tracking") {
            cleanedURL = URLCleaner.clean(url)
        } else {
            cleanedURL = url
        }

        pickerState.recordURLHistory(cleanedURL)

        // Rules only apply to networked URLs (need a host). Local files always pick.
        if !cleanedURL.isFileURL {
            let mode = RuleEngine.mode
            if mode == .rulesFirst || mode == .rulesOnly {
                if let rule = RuleEngine.match(url: cleanedURL) {
                    if let browser = pickerState.browsers.first(where: { $0.id == rule.browserID }) {
                        let profile = rule.profileID.flatMap { pid in browser.profiles.first(where: { $0.id == pid }) }
                        pickerState.recordUsage(browser, profile: profile)
                        BrowserLauncher.open(url: cleanedURL, in: browser, profile: profile)
                        return
                    }
                }
                if mode == .rulesOnly {
                    if let browser = pickerState.visibleBrowsers.first {
                        BrowserLauncher.open(url: cleanedURL, in: browser)
                    }
                    return
                }
            }
        }

        showPicker(for: cleanedURL)
    }

    private func showPicker(for url: URL) {
        urlLaunched = false
        pickerState.url = url
        pickerState.loadBrowsers()

        fitPicker()
        DispatchQueue.main.async { [weak self] in self?.fitPicker() }
        // orderFrontRegardless: LSUIElement + nonactivatingPanel often no-ops makeKeyAndOrderFront
        // when the open comes from another process (Terminal, VS Code task, etc.).
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func promptForFullDiskAccess() {
        let alert = NSAlert()
        alert.messageText = "Punt needs Full Disk Access"
        alert.informativeText = "macOS is hiding browser profiles. Full Disk Access opens next, with Punt in the list. Turn Punt on, then quit and reopen Punt."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Full Disk Access")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        FullDiskAccess.openSettings()
    }

    private func fitPicker() {
        panel.fitToContent()
        panel.centerOnScreen()
    }

    private func hidePanel() {
        if !urlLaunched && pickerState.url != nil {
            animatePanelToMenuBar()
        } else {
            panel.orderOut(nil)
            NSApp.hide(nil)
        }
    }

    private func animatePanelToMenuBar() {
        let target = menuBarManager.statusItemFrame
        let originalFrame = panel.frame

        guard !target.isEmpty else {
            panel.orderOut(nil)
            NSApp.hide(nil)
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.panel.setFrame(originalFrame, display: false)
            NSApp.hide(nil)
        })
    }

    private func launchURL(in browser: Browser, profile: BrowserProfile?) {
        guard let url = pickerState.url else { return }
        pickerState.recordUsage(browser, profile: profile)
        urlLaunched = true
        hidePanel()
        BrowserLauncher.open(url: url, in: browser, profile: profile)
    }

    // MARK: - Keyboard

    private func registerLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            guard self.panel.isVisible else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+Q to quit
            if event.keyCode == 12 && flags.contains(.command) {
                NSApp.terminate(nil)
                return nil
            }

            // Allow arrow keys (they set numericPad + function flags)
            guard flags.subtracting([.capsLock, .numericPad, .function]).isEmpty else { return event }

            switch event.keyCode {
            case 53:  // Escape
                if !self.pickerState.profileQuery.isEmpty {
                    self.pickerState.profileQuery = ""
                } else {
                    self.hidePanel()
                }
                return nil
            case 36:  // Return
                if let browser = self.pickerState.selectedBrowser {
                    self.launchURL(in: browser, profile: self.pickerState.selectedProfile)
                }
                return nil
            case 123: // Left arrow
                self.pickerState.moveLeft()
                return nil
            case 124: // Right arrow
                self.pickerState.moveRight()
                return nil
            case 125: // Down arrow
                self.pickerState.moveDown()
                return nil
            case 126: // Up arrow
                self.pickerState.moveUp()
                return nil
            case 51:  // Backspace
                self.pickerState.backspaceProfileQuery()
                return nil
            default:
                break
            }

            // Number keys 1-9: always select browser (no conflict with profiles)
            if let digit = self.digitFromKeyCode(event.keyCode), digit >= 1, digit <= 9 {
                let index = digit - 1
                let visible = self.pickerState.visibleBrowsers
                if index < visible.count {
                    self.launchURL(in: visible[index], profile: nil)
                }
                return nil
            }

            // Letter keys: fuzzy filter profiles (only when browser has profiles)
            if let chars = event.characters, let char = chars.first, char.isLetter {
                if self.pickerState.hasProfiles {
                    self.pickerState.appendToProfileQuery(char)
                    return nil
                }
            }

            return event
        }
    }

    private func registerClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }
            if self.panel.containsMouse(NSEvent.mouseLocation) { return }
            self.hidePanel()
        }
    }

    // MARK: - Settings

    private func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(state: pickerState)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Punt Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Default Browser

    private func promptSetDefaultBrowser() {
        guard let appURL = Bundle.main.bundleURL as URL? else { return }
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http") { error in
            if let error = error {
                NSLog("Failed to set default for http: \(error)")
            }
        }
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https") { error in
            if let error = error {
                NSLog("Failed to set default for https: \(error)")
            }
        }
    }

    // MARK: - Login Item

    private func enableLoginItem() {
        let service = SMAppService.mainApp
        if service.status != .enabled {
            try? service.register()
        }
    }

    // MARK: - Helpers

    private func digitFromKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        default: return nil
        }
    }
}
