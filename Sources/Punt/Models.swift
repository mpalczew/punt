import Foundation

struct Browser: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let url: URL
    var profiles: [BrowserProfile]
    var isHidden: Bool
    var profilesNeedAccess: Bool

    init(id: String, name: String, url: URL, profiles: [BrowserProfile] = [], isHidden: Bool = false, profilesNeedAccess: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.profiles = profiles
        self.isHidden = isHidden
        self.profilesNeedAccess = profilesNeedAccess
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
    let directoryName: String
    let displayName: String

    static func == (lhs: BrowserProfile, rhs: BrowserProfile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Rule: Identifiable, Codable {
    let id: UUID
    var domain: String
    var sourceApp: String
    var browserID: String
    var profileID: String?

    init(id: UUID = UUID(), domain: String, sourceApp: String = "*", browserID: String, profileID: String? = nil) {
        self.id = id
        self.domain = domain
        self.sourceApp = sourceApp
        self.browserID = browserID
        self.profileID = profileID
    }
}

enum PickerMode: String, Codable {
    case always
    case rulesFirst
    case rulesOnly
}
