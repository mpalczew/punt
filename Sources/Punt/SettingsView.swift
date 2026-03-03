import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: PickerState
    @State private var selectedTab = 0
    @State private var rules: [Rule] = RuleEngine.rules
    @State private var pickerMode: PickerMode = RuleEngine.mode
    @State private var stripTracking: Bool = UserDefaults.standard.bool(forKey: "punt_strip_tracking")

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            browsersTab
                .tabItem { Label("Browsers", systemImage: "globe") }
                .tag(1)

            rulesTab
                .tabItem { Label("Rules", systemImage: "list.bullet") }
                .tag(2)

            privacyTab
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
                .tag(3)
        }
        .frame(width: 480, height: 360)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Picker("Picker mode", selection: $pickerMode) {
                Text("Always show picker").tag(PickerMode.always)
                Text("Check rules first, then picker").tag(PickerMode.rulesFirst)
                Text("Rules only (no picker)").tag(PickerMode.rulesOnly)
            }
            .onChange(of: pickerMode) { newValue in
                RuleEngine.mode = newValue
            }

            Section {
                Text("Punt v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Browsers

    private var browsersTab: some View {
        List {
            ForEach(state.browsers) { browser in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: browser.url.path))
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text(browser.name)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { !browser.isHidden },
                        set: { visible in
                            state.setHidden(browser.id, hidden: !visible)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Rules

    private var rulesTab: some View {
        VStack {
            List {
                ForEach(rules) { rule in
                    HStack {
                        Text(rule.domain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("→")
                        Text(browserName(for: rule.browserID))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .onDelete { indexSet in
                    rules.remove(atOffsets: indexSet)
                    RuleEngine.rules = rules
                }
            }

            HStack {
                Spacer()
                Button("Add Rule…") {
                    let newRule = Rule(domain: "example.com", browserID: state.browsers.first?.id ?? "")
                    rules.append(newRule)
                    RuleEngine.rules = rules
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Privacy

    private var privacyTab: some View {
        Form {
            Toggle("Strip tracking parameters from URLs", isOn: $stripTracking)
                .onChange(of: stripTracking) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "punt_strip_tracking")
                }

            Text("When enabled, Punt removes common tracking parameters (utm_*, fbclid, gclid, etc.) from URLs before opening them.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func browserName(for id: String) -> String {
        state.browsers.first(where: { $0.id == id })?.name ?? id
    }
}
