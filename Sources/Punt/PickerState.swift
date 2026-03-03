import AppKit
import Foundation

class PickerState: ObservableObject {
    @Published var url: URL?
    @Published var browsers: [Browser] = []
    @Published var selectedIndex: Int = 0

    private static let recencyKey = "punt_recency"
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

    func loadBrowsers() {
        var discovered = BrowserDiscovery.discoverBrowsers()
        let hidden = hiddenBrowserIds()
        for i in discovered.indices {
            discovered[i].isHidden = hidden.contains(discovered[i].id)
        }
        // Sort by recency, then alphabetical
        let ranks = recencyRanks()
        browsers = discovered.sorted { a, b in
            let ra = ranks[a.id] ?? Int.max
            let rb = ranks[b.id] ?? Int.max
            if ra != rb { return ra < rb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        selectedIndex = 0
    }

    func recordUsage(_ browser: Browser) {
        var entries = recencyList()
        entries.removeAll { $0 == browser.id }
        entries.insert(browser.id, at: 0)
        if entries.count > Self.maxRecent {
            entries = Array(entries.prefix(Self.maxRecent))
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.recencyKey)
        }
    }

    func moveLeft() {
        let count = visibleBrowsers.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }

    func moveRight() {
        let count = visibleBrowsers.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
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

    private func hiddenBrowserIds() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: Self.hiddenKey),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(list)
    }
}
