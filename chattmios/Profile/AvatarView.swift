import SwiftUI

/// Circular avatar: shows the uploaded image, or a deterministic colored initial.
struct AvatarView: View {
    let username: String
    let avatarURL: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }

    private var placeholder: some View {
        ZStack {
            Color.deterministic(from: username)
            Text(initial)
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var initial: String {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "?" : String(trimmed.first!).uppercased()
    }
}

/// Small status dot for presence.
struct StatusDot: View {
    let status: PresenceStatus
    var size: CGFloat = 10

    var color: Color {
        switch status {
        case .online: return Color(hexString: "#3ba55c") ?? .green
        case .idle: return Color(hexString: "#faa61a") ?? .yellow
        case .dnd: return Color(hexString: "#ed4245") ?? .red
        case .offline: return Color(hexString: "#72767d") ?? .gray
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Brand.background, lineWidth: 2))
    }
}

/// Owner crown / verified / guest badges shown beside a name.
struct UserBadges: View {
    var isOwner: Bool = false
    var verified: Bool = false
    var redVerified: Bool = false
    var isGuest: Bool = false

    private static let redGradient = LinearGradient(
        colors: [Color(hexString: "#3d0a0f") ?? .red, Color(hexString: "#5a151c") ?? .red],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        HStack(spacing: 3) {
            // Priority: owner > red verified > blue verified
            if isOwner {
                sealBadge(Brand.accent)
            } else if redVerified {
                Image(systemName: "checkmark.seal.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Self.redGradient)
            } else if verified {
                sealBadge(Brand.verified)
            }
            if isGuest {
                Text("guest")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(.gray.opacity(0.3), in: .capsule)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
    }

    /// Scalloped seal with a white checkmark, tinted by `color`.
    private func sealBadge(_ color: Color) -> some View {
        Image(systemName: "checkmark.seal.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
    }
}
