import SwiftUI

/// Compact profile card shown from the chat top-left avatar button.
struct SelfInfoPopover: View {
    let username: String
    let profile: UserProfile?
    @Environment(AuthManager.self) private var auth

    private var status: PresenceStatus { profile?.status ?? .online }

    var body: some View {
        VStack(spacing: 12) {
            AvatarView(username: username, avatarURL: profile?.avatar, size: 68)

            HStack(spacing: 6) {
                ColoredName(name: username, color: NameColor(raw: profile?.color),
                            font: .headline, fallback: .primary)
                UserBadges(isOwner: profile?.isOwner ?? false,
                           verified: profile?.verified ?? false,
                           isGuest: profile?.isGuest ?? false)
            }

            HStack(spacing: 6) {
                StatusDot(status: status)
                Text(status.label).font(.subheadline).foregroundStyle(.secondary)
            }

            if let pronouns = profile?.pronouns, !pronouns.isEmpty {
                Text(pronouns).font(.caption).foregroundStyle(.secondary)
            }
            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(role: .destructive) {
                Task { await auth.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .padding(20)
        .frame(minWidth: 230)
        .presentationCompactAdaptation(.popover)
    }
}
