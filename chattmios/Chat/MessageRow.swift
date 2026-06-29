import SwiftUI

struct MessageRow: View {
    let message: Message
    let emojiMap: [String: String]
    let showsHeader: Bool      // false when grouped under the previous message
    let authorIsOwner: Bool    // derived from the userlist (messages don't carry it)
    let currentUsername: String?
    let canModerate: Bool

    var onProfile: (String) -> Void
    var onDelete: (Message) -> Void
    var onImage: (URL) -> Void
    var onMention: (String) -> Void

    @GestureState private var swipeOffset: CGFloat = 0

    private var isMine: Bool {
        message.username.caseInsensitiveCompare(currentUsername ?? "") == .orderedSame
    }
    private var mentionsMe: Bool { message.mentions(username: currentUsername) }

    var body: some View {
        if message.system {
            systemRow
        } else {
            normalRow
        }
    }

    private var systemRow: some View {
        Text(message.text ?? "")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 4)
    }

    private var normalRow: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsHeader {
                Button { onProfile(message.username) } label: {
                    AvatarView(username: message.username, avatarURL: message.avatar, size: 38)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 38, height: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                if showsHeader {
                    HStack(spacing: 6) {
                        Button { onProfile(message.username) } label: {
                            ColoredName(name: message.username, color: message.nameColor)
                        }
                        .buttonStyle(.plain)
                        UserBadges(isOwner: authorIsOwner, verified: message.verified, isGuest: message.isGuest)
                        Text(message.time, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let text = message.text, !text.isEmpty {
                    MessageBodyView(text: text, emojiMap: emojiMap, mentionMe: mentionsMe,
                                    font: .body)
                }

                if let image = message.image, let url = URL(string: image) {
                    MessageAttachment(url: url) { onImage(url) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, showsHeader ? 14 : 3)
        .padding(.bottom, 3)
        .padding(.horizontal, 12)
        .background(
            mentionsMe ? Brand.accent.opacity(0.10) : Color.clear,
            in: .rect(cornerRadius: 10)
        )
        .offset(x: swipeOffset)
        .overlay(alignment: .leading) {
            Image(systemName: "at")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.accent)
                .padding(6)
                .background(Brand.accent.opacity(0.15), in: Circle())
                .scaleEffect(min(swipeOffset / 50, 1))
                .opacity(min(swipeOffset / 40, 1))
                .offset(x: swipeOffset * 0.25 - 28)
                .animation(.interactiveSpring, value: swipeOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .updating($swipeOffset) { value, state, _ in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard h > 0, abs(h) > abs(v) * 1.2 else { return }
                    state = min(h * 0.4, 70)
                }
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard h > 60, abs(h) > abs(v) * 1.2 else { return }
                    Haptics.tap()
                    onMention(message.username)
                }
        )
        .contextMenu {
            if let text = message.text, !text.isEmpty {
                Button { UIPasteboard.general.string = text } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            Button { onProfile(message.username) } label: {
                Label("View Profile", systemImage: "person.crop.circle")
            }
            if isMine || canModerate {
                Button(role: .destructive) { onDelete(message) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

/// Image/file attachment thumbnail.
private struct MessageAttachment: View {
    let url: URL
    var onTap: () -> Void

    private var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "svg"].contains(url.pathExtension.lowercased())
    }

    var body: some View {
        if isImage {
            Button(action: onTap) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackLink
                    default:
                        ProgressView().frame(width: 120, height: 120)
                    }
                }
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        } else {
            fallbackLink
        }
    }

    private var fallbackLink: some View {
        Link(destination: url) {
            Label(url.lastPathComponent, systemImage: "paperclip")
                .font(.callout)
                .padding(8)
                .glassPanel(cornerRadius: 10)
        }
    }
}
