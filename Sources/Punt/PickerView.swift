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
                Text(url.absoluteString)
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
            if let browser = state.selectedBrowser, !browser.profiles.isEmpty {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Profiles")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    ForEach(browser.profiles) { profile in
                        Text(profile.displayName)
                            .font(.system(size: 12))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(browser, profile)
                            }
                    }
                }
                .padding(.bottom, 8)
            }

            // Hint
            HStack(spacing: 12) {
                KeyCap("←→")
                Text("navigate")
                KeyCap("⏎")
                Text("open")
                KeyCap("esc")
                Text("cancel")
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .padding(.bottom, 10)
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
                KeyCap("⌘\(n)")
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
