import AppKit
import SwiftUI

struct PickerView: View {
    @ObservedObject var state: PickerState
    let onSelect: (Browser, BrowserProfile?) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // URL display
            if let url = state.url {
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            // Browser grid
            HStack(spacing: 16) {
                ForEach(Array(state.visibleBrowsers.enumerated()), id: \.element.id) { index, browser in
                    BrowserCell(
                        browser: browser,
                        isSelected: index == state.selectedIndex,
                        shortcutNumber: index < 9 ? index + 1 : nil
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(browser, nil)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Profiles for selected browser (if any)
            if state.hasProfiles {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 2) {
                    // Search field for profiles
                    if !state.profileQuery.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(state.profileQuery)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                    }

                    ForEach(Array(state.filteredProfiles.enumerated()), id: \.element.id) { index, profile in
                        HStack(spacing: 8) {
                            Text(profile.displayName)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == state.selectedProfileIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(state.selectedBrowser!, profile)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(minWidth: 200)
        .background(VisualEffectBlur())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BrowserCell: View {
    let browser: Browser
    let isSelected: Bool
    let shortcutNumber: Int?

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: browser.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            Text(browser.name)
                .font(.system(size: 11))
                .lineLimit(1)

            if let n = shortcutNumber {
                KeyCap("\(n)")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
    }
}

struct KeyCap: View {
    let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
            )
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
