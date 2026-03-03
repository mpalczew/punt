import AppKit
import Foundation

enum BrowserDiscovery {
    private static let chromiumBundleIds: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "company.thebrowser.Browser",  // Arc
    ]

    static func discoverBrowsers() -> [Browser] {
        let handlers = LSCopyAllHandlersForURLScheme("https" as CFString)?.takeRetainedValue() as? [String] ?? []

        var seen = Set<String>()
        var browsers: [Browser] = []

        for bundleId in handlers {
            let lowered = bundleId.lowercased()
            guard lowered != "com.punt.browser-picker" else { continue }
            guard !seen.contains(lowered) else { continue }
            seen.insert(lowered)

            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { continue }
            let name = displayName(for: appURL)
            var profiles: [BrowserProfile] = []

            if chromiumBundleIds.contains(bundleId) {
                profiles = discoverChromiumProfiles(bundleId: bundleId)
            }

            browsers.append(Browser(
                id: bundleId,
                name: name,
                url: appURL,
                profiles: profiles
            ))
        }

        return browsers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func displayName(for appURL: URL) -> String {
        if let bundle = Bundle(url: appURL),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
               ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    private static func discoverChromiumProfiles(bundleId: String) -> [BrowserProfile] {
        guard let supportDir = chromiumSupportDir(for: bundleId) else { return [] }

        let localStatePath = supportDir.appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: localStatePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileInfo = json["profile"] as? [String: Any],
              let infoCache = profileInfo["info_cache"] as? [String: Any] else {
            return []
        }

        // First pass: collect raw names to detect collisions
        var rawNames: [String: Int] = [:]
        for (_, value) in infoCache {
            guard let info = value as? [String: Any] else { continue }
            let name = info["name"] as? String ?? ""
            rawNames[name, default: 0] += 1
        }

        var profiles: [BrowserProfile] = []
        var seenDirs = Set<String>()
        for (dirName, value) in infoCache {
            guard let info = value as? [String: Any] else { continue }
            guard !seenDirs.contains(dirName) else { continue }
            seenDirs.insert(dirName)

            let name = info["name"] as? String ?? dirName
            let email = info["user_name"] as? String

            // Use "Name (email)" when names collide, otherwise just "Name"
            let displayName: String
            if let email = email, (rawNames[name] ?? 0) > 1 {
                displayName = "\(name) (\(email))"
            } else if let email = email, name == email {
                // Name IS the email — use gaia_name if available
                let gaiaName = info["gaia_name"] as? String
                displayName = gaiaName != nil ? "\(gaiaName!) (\(email))" : email
            } else {
                displayName = name
            }

            profiles.append(BrowserProfile(
                browserBundleId: bundleId,
                directoryName: dirName,
                displayName: displayName
            ))
        }

        return profiles.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func chromiumSupportDir(for bundleId: String) -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let dirName: String
        switch bundleId {
        case "com.google.Chrome": dirName = "Google/Chrome"
        case "com.google.Chrome.canary": dirName = "Google/Chrome Canary"
        case "com.brave.Browser": dirName = "BraveSoftware/Brave-Browser"
        case "com.microsoft.edgemac": dirName = "Microsoft Edge"
        case "com.vivaldi.Vivaldi": dirName = "Vivaldi"
        case "com.operasoftware.Opera": dirName = "com.operasoftware.Opera"
        case "company.thebrowser.Browser": dirName = "Arc"
        default: return nil
        }

        let dir = appSupport.appendingPathComponent(dirName)
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }
}
