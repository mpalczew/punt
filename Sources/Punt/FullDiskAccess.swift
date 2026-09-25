import AppKit
import Darwin

enum FullDiskAccess {
    /// Opening this file is what puts the app in the Full Disk Access list.
    private static let registrationPath = "/Library/Application Support/com.apple.TCC/TCC.db"
    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
    ]

    /// Must run before AppKit starts. A later open is treated as a preflight and
    /// macOS does not add Punt to the Full Disk Access list.
    static func registerForSettingsList() {
        let fd = Darwin.open(registrationPath, O_RDONLY)
        if fd >= 0 { Darwin.close(fd) }
    }

    static func openSettings() {
        for raw in settingsURLs {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
