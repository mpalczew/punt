import AppKit
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PickerPanel!
    private var pickerState: PickerState!
    private var menuBarManager: MenuBarManager!
    private var settingsWindow: NSWindow?
    private var localMonitor: Any?
    private var clickMonitor: Any?
    private let autoUpdater = AutoUpdater()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        pickerState = PickerState()
        pickerState.loadBrowsers()

        let panelRect = NSRect(x: 0, y: 0, width: 600, height: 200)
        panel = PickerPanel(contentRect: panelRect)

        let pickerView = PickerView(
            state: pickerState,
            onSelect: { [weak self] browser, profile in self?.launchURL(in: browser, profile: profile) },
            onDismiss: { [weak self] in self?.hidePanel() }
        )
        panel.contentView = NSHostingView(rootView: pickerView)

        menuBarManager = MenuBarManager()
        menuBarManager.onSetDefault = { [weak self] in self?.promptSetDefaultBrowser() }
        menuBarManager.onShowSettings = { [weak self] in self?.showSettings() }
        menuBarManager.onQuit = { NSApp.terminate(nil) }
        menuBarManager.setup()

        registerLocalMonitor()
        registerClickOutsideMonitor()

        autoUpdater.isPanelHidden = { [weak self] in !(self?.panel.isVisible ?? false) }
        autoUpdater.startMonitoring()

        if !UserDefaults.standard.bool(forKey: "punt_has_launched") {
            UserDefaults.standard.set(true, forKey: "punt_has_launched")
            enableLoginItem()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.promptSetDefaultBrowser()
            }
        }
    }

    // MARK: - URL Handling

    func application(_ sender: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        showPicker(for: url)
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }

        let cleanedURL: URL
        if UserDefaults.standard.bool(forKey: "punt_strip_tracking") {
            cleanedURL = URLCleaner.clean(url)
        } else {
            cleanedURL = url
        }

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

        showPicker(for: cleanedURL)
    }

    private func showPicker(for url: URL) {
        pickerState.url = url
        pickerState.loadBrowsers()

        let browserCount = pickerState.visibleBrowsers.count
        let width = CGFloat(max(browserCount, 3)) * 80 + 32
        panel.setContentSize(NSSize(width: min(width, 800), height: 200))
        panel.centerOnScreen()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePanel() {
        panel.orderOut(nil)
        NSApp.hide(nil)
    }

    private func launchURL(in browser: Browser, profile: BrowserProfile?) {
        guard let url = pickerState.url else { return }
        pickerState.recordUsage(browser, profile: profile)
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
