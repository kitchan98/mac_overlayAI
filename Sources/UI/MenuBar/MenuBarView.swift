import SwiftUI

struct MenuBarView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status
            HStack {
                Circle()
                    .fill(SecureStorage.shared.hasAPIKey ? .green : .orange)
                    .frame(width: 8, height: 8)

                Text(SecureStorage.shared.hasAPIKey ? "Ready" : "API Key Required")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Hotkey hint
            HStack {
                Text("Hotkey:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌘⌥A")
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Settings
            Button(action: openSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                }
            }
            .keyboardShortcut(",")
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Text Assistant")
                }
            }
            .keyboardShortcut("q")
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 200)
    }
}
