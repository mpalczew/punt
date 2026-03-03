import Foundation

enum RuleEngine {
    private static let rulesKey = "punt_rules"
    private static let modeKey = "punt_picker_mode"

    static var mode: PickerMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: modeKey),
                  let m = PickerMode(rawValue: raw) else { return .always }
            return m
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    static var rules: [Rule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: rulesKey),
                  let r = try? JSONDecoder().decode([Rule].self, from: data) else { return [] }
            return r
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: rulesKey)
            }
        }
    }

    /// Returns the matching rule for a URL, or nil if no rule matches.
    static func match(url: URL, sourceAppBundleId: String? = nil) -> Rule? {
        guard let host = url.host?.lowercased() else { return nil }

        for rule in rules {
            // Check source app
            if rule.sourceApp != "*" {
                guard let source = sourceAppBundleId, rule.sourceApp == source else { continue }
            }

            // Check domain
            if rule.domain == "*" {
                return rule
            }

            if host == rule.domain || host.hasSuffix("." + rule.domain) {
                return rule
            }
        }

        return nil
    }
}
