import AppKit
import Foundation

class AutoUpdater {
    static let autoUpdateEnabledKey = "punt_auto_update_enabled"
    private static let lastUpdateCheckKey = "punt_last_update_check"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private var checkTimer: Timer?
    private var isUpdateInProgress = false

    /// Set by AppDelegate to query panel visibility.
    var isPanelHidden: () -> Bool = { true }

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoUpdateEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoUpdateEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoUpdateEnabledKey)
        }
    }

    func startMonitoring() {
        guard AutoUpdater.isEnabled else {
            NSLog("Punt: Auto-update disabled by user preference")
            return
        }

        if HomebrewDetector.isHomebrewManaged {
            NSLog("Punt: Homebrew installation detected")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.performCheck()
        }

        checkTimer = Timer.scheduledTimer(
            withTimeInterval: 60 * 60,
            repeats: true
        ) { [weak self] _ in
            self?.checkIfDue()
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func checkNow(completion: @escaping (String) -> Void) {
        let currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"

        UpdateChecker.fetchLatestRelease { result in
            switch result {
            case .failure(let error):
                completion("Update check failed: \(error)")
            case .success(let release):
                if UpdateChecker.isNewer(remote: release.version, local: currentVersion) {
                    completion("Update available: \(currentVersion) -> \(release.version)")
                } else {
                    completion("Up to date (current: \(currentVersion), latest: \(release.version))")
                }
            }
        }
    }

    private func checkIfDue() {
        guard AutoUpdater.isEnabled, !isUpdateInProgress else { return }

        let lastCheck = UserDefaults.standard.object(
            forKey: Self.lastUpdateCheckKey
        ) as? Date ?? .distantPast
        guard Date().timeIntervalSince(lastCheck) >= Self.checkInterval else { return }

        performCheck()
    }

    private func performCheck() {
        UserDefaults.standard.set(Date(), forKey: Self.lastUpdateCheckKey)

        UpdateChecker.fetchLatestRelease { [weak self] result in
            switch result {
            case .failure(let error):
                NSLog("Punt: Update check failed: \(error)")
            case .success(let release):
                self?.handleRelease(release)
            }
        }
    }

    private func handleRelease(_ release: UpdateChecker.Release) {
        let currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"

        guard UpdateChecker.isNewer(remote: release.version, local: currentVersion) else {
            NSLog("Punt: Up to date (current: \(currentVersion), latest: \(release.version))")
            return
        }

        NSLog("Punt: Update available: \(currentVersion) -> \(release.version)")
        waitForPanelHidden { [weak self] in
            self?.applyUpdate(release)
        }
    }

    private func waitForPanelHidden(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isPanelHidden() {
                completion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.waitForPanelHidden(completion: completion)
                }
            }
        }
    }

    private func applyUpdate(_ release: UpdateChecker.Release) {
        guard !isUpdateInProgress else { return }
        isUpdateInProgress = true

        NSLog("Punt: Downloading update \(release.version)...")

        UpdateInstaller.downloadAndInstall(from: release.downloadURL) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUpdateInProgress = false

                switch result {
                case .failure(let error):
                    NSLog("Punt: Update installation failed: \(error)")
                case .success:
                    NSLog("Punt: Update installed successfully, relaunching...")
                    self?.relaunch()
                }
            }
        }
    }

    private func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [bundlePath, "--args", "--after-update"]
        try? task.run()
        NSApp.terminate(nil)
    }
}
