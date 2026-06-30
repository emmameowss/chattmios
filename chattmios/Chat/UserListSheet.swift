import SwiftUI

struct UserListSheet: View {
    @Environment(SocketService.self) private var socket
    @Environment(\.dismiss) private var dismiss
    var onProfile: (String) -> Void

    private var online: [ChatUserSummary] { socket.users.filter(\.online).sorted { $0.username.lowercased() < $1.username.lowercased() } }
    private var offline: [ChatUserSummary] { socket.users.filter { !$0.online }.sorted { $0.username.lowercased() < $1.username.lowercased() } }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Members").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
            listContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minWidth: 380, minHeight: 460)
        .dismissOnOutsideClick { dismiss() }
        #else
        NavigationStack {
            listContent
                .navigationTitle("Members")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #endif
    }

    private var listContent: some View {
        Group {
            if !socket.usersLoaded {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading members…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Online — \(online.count)") {
                        ForEach(online) { user in row(user) }
                    }
                    if !offline.isEmpty {
                        Section("Offline — \(offline.count)") {
                            ForEach(offline) { user in row(user) }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func row(_ user: ChatUserSummary) -> some View {
        Button {
            dismiss()
            onProfile(user.username)
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(username: user.username, avatarURL: user.avatar, size: 40)
                    StatusDot(status: user.effectiveStatus)
                        .offset(x: 2, y: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        ColoredName(name: user.username, color: user.nameColor, fallback: .primary)
                        UserBadges(isOwner: user.isOwner, verified: user.verified, redVerified: user.redVerified, isGuest: user.isGuest)
                    }
                    Text(subtitle(user))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ user: ChatUserSummary) -> String {
        if user.online { return user.effectiveStatus.label }
        if let seen = user.lastSeen {
            return "Last seen \(seen.formatted(.relative(presentation: .named)))"
        }
        return "Offline"
    }
}
