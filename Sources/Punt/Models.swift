import Foundation

struct Browser: Identifiable, Codable, Hashable {
    let id: String           // bundle identifier, e.g. "com.apple.Safari"
    let name: String
    let url: URL             // path to .app bundle
    var profiles: [BrowserProfile]
    var isHidden: Bool

    init(id: String, name: String, url: URL, profiles: [BrowserProfile] = [], isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.profiles = profiles
        self.isHidden = isHidden
    }

    static func == (lhs: Browser, rhs: Browser) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct BrowserProfile: Identifiable, Codable, Hashable {
    var id: String { "\(browserBundleId)|\(directoryName)" }
    let browserBundleId: String
    let directoryName: String   // e.g. "Default", "Profile 1"
    let displayName: String     // parsed from Local State or Preferences

    static func == (lhs: BrowserProfile, rhs: BrowserProfile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Rule: Identifiable, Codable {
    let id: UUID
    var domain: String          // e.g. "github.com", or "*" for catch-all
    var sourceApp: String       // bundle id of source app, or "*"
    var browserID: String       // Browser.id to route to
    var profileID: String?      // optional BrowserProfile.id

    init(id: UUID = UUID(), domain: String, sourceApp: String = "*", browserID: String, profileID: String? = nil) {
        self.id = id
        self.domain = domain
        self.sourceApp = sourceApp
        self.browserID = browserID
        self.profileID = profileID
    }
}

enum PickerMode: String, Codable {
    case always          // always show picker
    case rulesFirst      // check rules first, show picker if no match
    case rulesOnly       // only use rules, fall back to default browser
}
