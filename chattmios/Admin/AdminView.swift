import SwiftUI

/// Owner-only moderation surface. Each action sends the corresponding slash
/// command through the socket and/or hits the emoji-review REST endpoints.
struct AdminView: View {
    @Environment(SocketService.self) private var socket
    @Environment(AuthManager.self) private var auth

    @State private var actionSheet: ModAction?
    @State private var confirmation: String?

    private var me: String { auth.currentUsername ?? "owner" }

    var body: some View {
        List {
            Section("Users") {
                actionRow(.ban); actionRow(.unban); actionRow(.kick)
                actionRow(.mute); actionRow(.unmute); actionRow(.whois)
                actionRow(.verify); actionRow(.unverify)
                actionRow(.setColor); actionRow(.setNick); actionRow(.resetStrikes)
            }
            Section("Chat") {
                quickRow("Mute chat", icon: "speaker.slash") { run("/mutechat") }
                quickRow("Unmute chat", icon: "speaker.wave.2") { run("/unmutechat") }
                actionRow(.announce); actionRow(.status)
                destructiveRow("Clear all messages", icon: "trash") { run("/clear") }
            }
            Section("Access") {
                quickRow("Disable guests", icon: "person.fill.xmark") { run("/noguests") }
                quickRow("Allow guests", icon: "person.fill.checkmark") { run("/allowguests") }
                actionRow(.maintenance)
            }
            Section("Word Filter") {
                actionRow(.addFilter); actionRow(.removeFilter)
                quickRow("Reload filter", icon: "arrow.clockwise") { run("/reloadfilter") }
            }
            Section("Custom Emoji") {
                actionRow(.addEmoji); actionRow(.removeEmoji)
                quickRow("Reload emoji", icon: "arrow.clockwise") { run("/reloademojis") }
                NavigationLink {
                    EmojiReviewView()
                } label: {
                    Label("Review submissions", systemImage: "tray.full")
                }
            }
        }
        .navigationTitle("Moderation")
        .inlineNavigationTitle()
        .sheet(item: $actionSheet) { action in
            ModActionForm(action: action) { command in
                run(command)
                actionSheet = nil
            }
            .presentationDetents([.medium])
        }
        .overlay(alignment: .bottom) {
            if let confirmation {
                Text(confirmation)
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassCapsule(interactive: false)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func actionRow(_ action: ModAction) -> some View {
        Button { actionSheet = action } label: {
            Label(action.title, systemImage: action.icon)
        }
        .tint(action.destructive ? .red : nil)
    }

    private func quickRow(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button { perform() } label: { Label(title, systemImage: icon) }
    }

    private func destructiveRow(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(role: .destructive) { perform() } label: { Label(title, systemImage: icon) }
    }

    private func run(_ command: String) {
        socket.sendCommand(command, username: me)
        Haptics.success()
        withAnimation { confirmation = "Sent: \(command)" }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { confirmation = nil }
        }
    }
}
