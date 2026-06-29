import SwiftUI

/// Read-only profile for any user (fetched via the `getProfile` socket event).
struct ProfileView: View {
    let username: String
    @Environment(SocketService.self) private var socket
    @Environment(\.dismiss) private var dismiss

    private var profile: UserProfile? { socket.profiles[username] }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile {
                    ProfileHeader(profile: profile)
                    ProfileDetails(profile: profile)
                } else {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .navigationTitle(username)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { socket.getProfile(username) }
        }
    }
}

struct ProfileHeader: View {
    let profile: UserProfile

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(username: profile.username, avatarURL: profile.avatar, size: 110)
                StatusDot(status: profile.online ? profile.status : .offline, size: 22)
                    .offset(x: 4, y: 4)
            }
            HStack(spacing: 8) {
                ColoredName(name: profile.username, color: profile.nameColor,
                            font: .title2.weight(.bold), fallback: .primary)
                UserBadges(isOwner: profile.isOwner, verified: profile.verified, isGuest: profile.isGuest)
            }
            if !profile.pronouns.isEmpty {
                Text(profile.pronouns).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct ProfileDetails: View {
    let profile: UserProfile
    /// Hidden on your own profile, where an interactive status picker is shown instead.
    var showStatus: Bool = true

    private var rows: [(title: String, value: String)] {
        var result: [(String, String)] = []
        if showStatus {
            result.append(("Status", (profile.online ? profile.status : .offline).label))
        }
        if !profile.online, let seen = profile.lastSeen {
            result.append(("Last seen", seen.formatted(.relative(presentation: .named))))
        }
        if let email = profile.email, !email.isEmpty {
            result.append(("Email", email))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 16) {
            if !profile.bio.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio").font(.caption).foregroundStyle(.secondary)
                        Text(profile.bio).font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !rows.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Divider() }
                            detailRow(row.title, value: row.value)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
