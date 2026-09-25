import SwiftUI

struct ProfileAccessNotice: View {
    let browserName: String
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("macOS is hiding \(browserName) profiles.")
                .font(.system(size: 12, weight: .medium))
            Text("Turn on Full Disk Access for Punt, then quit and reopen Punt.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Set up access", action: onOpenSettings)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
