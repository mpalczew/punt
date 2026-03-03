import AppKit
import Foundation

enum BrowserLauncher {
    static func open(url: URL, in browser: Browser, profile: BrowserProfile? = nil) {
        if let profile = profile, isChromium(browser.id) {
            openChromiumWithProfile(url: url, browser: browser, profile: profile)
        } else {
            openWithWorkspace(url: url, browser: browser)
        }
    }

    private static func openWithWorkspace(url: URL, browser: Browser) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: browser.url,
            configuration: config
        )
    }

    private static func openChromiumWithProfile(url: URL, browser: Browser, profile: BrowserProfile) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [
            "-na", browser.url.path,
            "--args",
            "--profile-directory=\(profile.directoryName)",
            url.absoluteString
        ]
        try? task.run()
    }

    private static func isChromium(_ bundleId: String) -> Bool {
        let chromiumIds: Set<String> = [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.vivaldi.Vivaldi",
            "com.operasoftware.Opera",
            "company.thebrowser.Browser",
        ]
        return chromiumIds.contains(bundleId)
    }
}
