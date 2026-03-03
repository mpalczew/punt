import AppKit
import Foundation

class PickerState: ObservableObject {
    @Published var url: URL?
    @Published var browsers: [Browser] = []
    @Published var selectedIndex: Int = 0
    @Published var selectedProfileIndex: Int = -1  // -1 = no profile selected (default browser)
    @Published var profileQuery: String = "" {
        didSet { updateFilteredProfiles() }
    }
    @Published var filteredProfiles: [BrowserProfile] = []

    private static let recencyKey = "punt_recency"
    private static let profileRecencyKey = "punt_profile_recency"
    private static let hiddenKey = "punt_hidden_browsers"
    private static let maxRecent = 20

    var visibleBrowsers: [Browser] {
        browsers.filter { !$0.isHidden }
    }

    var selectedBrowser: Browser? {
        let visible = visibleBrowsers
        guard visible.indices.contains(selectedIndex) else { return nil }
        return visible[selectedIndex]
    }

    var selectedProfile: BrowserProfile? {
        guard selectedProfileIndex >= 0,
              selectedProfileIndex < filteredProfiles.count else { return nil }
        return filteredProfiles[selectedProfileIndex]
    }

    /// Whether the selected browser has profiles to navigate
    var hasProfiles: Bool {
        selectedBrowser?.profiles.isEmpty == false
    }

    func loadBrowsers() {
        var discovered = BrowserDiscovery.discoverBrowsers()
        let hidden = hiddenBrowserIds()
        let profRanks = profileRecencyRanks()
        for i in discovered.indices {
            discovered[i].isHidden = hidden.contains(discovered[i].id)
            // Sort profiles by recency
            discovered[i].profiles.sort { a, b in
                let ra = profRanks[a.id] ?? Int.max
                let rb = profRanks[b.id] ?? Int.max
                if ra != rb { return ra < rb }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            }
        }
        // Sort browsers by recency, then alphabetical
        let ranks = recencyRanks()
        browsers = discovered.sorted { a, b in
            let ra = ranks[a.id] ?? Int.max
            let rb = ranks[b.id] ?? Int.max
            if ra != rb { return ra < rb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        selectedIndex = 0
        selectedProfileIndex = -1
        profileQuery = ""
        updateFilteredProfiles()
    }

    func recordUsage(_ browser: Browser, profile: BrowserProfile? = nil) {
        var entries = recencyList()
        entries.removeAll { $0 == browser.id }
        entries.insert(browser.id, at: 0)
        if entries.count > Self.maxRecent {
            entries = Array(entries.prefix(Self.maxRecent))
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.recencyKey)
        }
        if let profile = profile {
            recordProfileUsage(profile)
        }
    }

    func moveLeft() {
        let count = visibleBrowsers.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
        resetProfileSelection()
    }

    func moveRight() {
        let count = visibleBrowsers.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
        resetProfileSelection()
    }

    func moveUp() {
        guard hasProfiles else { return }
        if selectedProfileIndex > -1 {
            selectedProfileIndex -= 1
        }
    }

    func moveDown() {
        guard hasProfiles else { return }
        if selectedProfileIndex < filteredProfiles.count - 1 {
            selectedProfileIndex += 1
        }
    }

    func appendToProfileQuery(_ char: Character) {
        profileQuery.append(char)
    }

    func backspaceProfileQuery() {
        if !profileQuery.isEmpty {
            profileQuery.removeLast()
        }
    }

    private func resetProfileSelection() {
        profileQuery = ""
        selectedProfileIndex = -1
        updateFilteredProfiles()
    }

    private func updateFilteredProfiles() {
        guard let browser = selectedBrowser else {
            filteredProfiles = []
            return
        }
        if profileQuery.isEmpty {
            filteredProfiles = browser.profiles
        } else {
            let q = profileQuery.lowercased()
            filteredProfiles = browser.profiles.filter { profile in
                fuzzyMatch(name: profile.displayName.lowercased(), query: q)
            }
        }
        // Auto-select first match when typing
        if !filteredProfiles.isEmpty && !profileQuery.isEmpty {
            selectedProfileIndex = 0
        } else if profileQuery.isEmpty {
            selectedProfileIndex = -1
        }
    }

    private func fuzzyMatch(name: String, query: String) -> Bool {
        var nameIdx = name.startIndex
        var queryIdx = query.startIndex
        while nameIdx < name.endIndex && queryIdx < query.endIndex {
            if name[nameIdx] == query[queryIdx] {
                queryIdx = query.index(after: queryIdx)
            }
            nameIdx = name.index(after: nameIdx)
        }
        return queryIdx == query.endIndex
    }

    func setHidden(_ browserId: String, hidden: Bool) {
        var ids = hiddenBrowserIds()
        if hidden {
            ids.insert(browserId)
        } else {
            ids.remove(browserId)
        }
        if let data = try? JSONEncoder().encode(Array(ids)) {
            UserDefaults.standard.set(data, forKey: Self.hiddenKey)
        }
        if let idx = browsers.firstIndex(where: { $0.id == browserId }) {
            browsers[idx].isHidden = hidden
        }
    }

    // MARK: - Private

    private func recordProfileUsage(_ profile: BrowserProfile) {
        var entries = profileRecencyList()
        entries.removeAll { $0 == profile.id }
        entries.insert(profile.id, at: 0)
        if entries.count > Self.maxRecent {
            entries = Array(entries.prefix(Self.maxRecent))
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.profileRecencyKey)
        }
    }

    private func recencyList() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: Self.recencyKey),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }

    private func recencyRanks() -> [String: Int] {
        var ranks: [String: Int] = [:]
        for (i, id) in recencyList().enumerated() {
            ranks[id] = i
        }
        return ranks
    }

    private func profileRecencyList() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: Self.profileRecencyKey),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }

    private func profileRecencyRanks() -> [String: Int] {
        var ranks: [String: Int] = [:]
        for (i, id) in profileRecencyList().enumerated() {
            ranks[id] = i
        }
        return ranks
    }

    private func hiddenBrowserIds() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: Self.hiddenKey),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(list)
    }
}
