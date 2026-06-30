import SwiftUI

struct ChatView: View {
    @Environment(SocketService.self) private var socket
    @Environment(AuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings

    @State private var model: ChatViewModel?

    var body: some View {
        Group {
            if let model {
                ChatScreen(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                model = ChatViewModel(socket: socket, auth: auth, settings: settings)
            }
        }
    }
}

private struct ProfileTarget: Identifiable { let id: String }

private struct ChatScreen: View {
    @Bindable var model: ChatViewModel
    @Environment(SocketService.self) private var socket

    @State private var showUserList = false
    @State private var showSelfInfo = false
    @State private var imageURL: IdentifiableURL?
    @State private var profileTarget: ProfileTarget?

    private var myProfile: UserProfile? { socket.profiles[model.username] }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                HStack(spacing: 0) {
                    chatArea
                    Divider()
                    MemberSidebar { name in profileTarget = ProfileTarget(id: name) }
                        .frame(width: 220)
                }
                #else
                chatArea
                #endif
            }
            .navigationTitle("chat™")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    Button { showSelfInfo = true } label: {
                        AvatarView(username: model.username, avatarURL: myProfile?.avatar, size: 30)
                    }
                    .popover(isPresented: $showSelfInfo) {
                        SelfInfoPopover(username: model.username, profile: myProfile)
                    }
                }
                ToolbarItem(placement: .leadingBar) { connectionBadge }
                #if !os(macOS)
                ToolbarItem(placement: .trailingBar) {
                    Button { showUserList = true } label: {
                        Label("\(socket.users.filter(\.online).count)", systemImage: "person.2.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showUserList) {
                UserListSheet { name in profileTarget = ProfileTarget(id: name) }
            }
            .sheet(item: $imageURL) { item in
                ImageViewerView(url: item.url)
            }
            .sheet(item: $profileTarget) { target in
                ProfileView(username: target.id)
            }
            .task { socket.getProfile(model.username) }
            .onChange(of: socket.connection) { _, state in
                if state == .connected { socket.getProfile(model.username) }
            }
        }
        .fillAvailableSpace()
    }

    private var chatArea: some View {
        messageList
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 6) {
                    if !socket.typingUsers.isEmpty {
                        TypingIndicatorView(names: Array(socket.typingUsers).sorted())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    let toast = socket.commandError
                    let mute = socket.muteNotice
                    let status = socket.serverStatus
                    if let msg = toast ?? mute ?? status {
                        Text(msg)
                            .font(.dmMono(13))
                            .foregroundStyle(Brand.accent)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    MessageComposer(model: model)
                }
                .animation(.easeInOut(duration: 0.2), value: socket.commandError)
                .animation(.easeInOut(duration: 0.2), value: socket.muteNotice)
                .animation(.easeInOut(duration: 0.2), value: socket.serverStatus)
            }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(socket.messages.enumerated()), id: \.element.id) { index, message in
                        MessageRow(
                            message: message,
                            emojiMap: socket.emojiMap,
                            showsHeader: showsHeader(at: index),
                            authorIsOwner: isOwner(username: message.username),
                            currentUsername: model.username,
                            canModerate: socket.isOwner,
                            onProfile: { profileTarget = ProfileTarget(id: $0) },
                            onDelete: { model.delete($0) },
                            onImage: { imageURL = IdentifiableURL(url: $0) },
                            onMention: { username in
                                let prefix = model.composerText.isEmpty ? "" : model.composerText.hasSuffix(" ") ? "" : " "
                                model.composerText += "\(prefix)@\(username) "
                                model.focusRequest = true
                            }
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.top, 8)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: socket.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: socket.connection) { _, state in
                if state == .connected {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionBadge: some View {
        switch socket.connection {
        case .connected:
            EmptyView()
        case .connecting, .idle:
            HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("Connecting").font(.caption2) }
                .foregroundStyle(.secondary)
                .lineLimit(1).fixedSize()
        case .disconnected, .failed:
            HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("Reconnecting").font(.caption2) }
                .foregroundStyle(.orange)
                .lineLimit(1).fixedSize()
        }
    }

    private func isOwner(username: String) -> Bool {
        if let user = socket.users.first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) {
            return user.isOwner
        }
        return socket.profiles[username]?.isOwner ?? false
    }

    private func showsHeader(at index: Int) -> Bool {
        let messages = socket.messages
        guard index > 0 else { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        if current.system || previous.system { return true }
        if current.username != previous.username { return true }
        return current.time.timeIntervalSince(previous.time) > 5 * 60
    }
}

#if os(macOS)
private struct MemberSidebar: View {
    @Environment(SocketService.self) private var socket
    var onProfile: (String) -> Void

    private var online: [ChatUserSummary] {
        socket.users.filter(\.online).sorted { $0.username.lowercased() < $1.username.lowercased() }
    }
    private var offline: [ChatUserSummary] {
        socket.users.filter { !$0.online }.sorted { $0.username.lowercased() < $1.username.lowercased() }
    }

    var body: some View {
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

    private func row(_ user: ChatUserSummary) -> some View {
        Button { onProfile(user.username) } label: {
            HStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(username: user.username, avatarURL: user.avatar, size: 28)
                    StatusDot(status: user.effectiveStatus)
                        .offset(x: 2, y: 2)
                }
                HStack(spacing: 4) {
                    ColoredName(name: user.username, color: user.nameColor, fallback: .primary)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    UserBadges(isOwner: user.isOwner, verified: user.verified, redVerified: user.redVerified, isGuest: user.isGuest)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
