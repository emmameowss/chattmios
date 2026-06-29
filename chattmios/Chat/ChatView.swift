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
    @State private var atBottom = true

    private var myProfile: UserProfile? { socket.profiles[model.username] }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                messageList
                VStack(spacing: 6) {
                    if !socket.typingUsers.isEmpty {
                        TypingIndicatorView(names: Array(socket.typingUsers).sorted())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    let toast = socket.commandError
                    let status = socket.serverStatus
                    if let msg = toast ?? status {
                        Text(msg)
                            .font(.dmMono(13))
                            .foregroundStyle(Brand.accent)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    MessageComposer(model: model)
                }
                .animation(.easeInOut(duration: 0.2), value: socket.commandError)
                .animation(.easeInOut(duration: 0.2), value: socket.serverStatus)
            }
            .navigationTitle("chat™")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSelfInfo = true } label: {
                        AvatarView(username: model.username, avatarURL: myProfile?.avatar, size: 30)
                    }
                    .popover(isPresented: $showSelfInfo) {
                        SelfInfoPopover(username: model.username, profile: myProfile)
                    }
                }
                ToolbarItem(placement: .topBarLeading) { connectionBadge }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showUserList = true } label: {
                        Label("\(socket.users.filter(\.online).count)", systemImage: "person.2.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                    }
                }
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
            .alert("Notice", isPresented: noticeBinding) {
                Button("OK", role: .cancel) { socket.notice = nil }
            } message: {
                Text(socket.notice ?? "")
            }
            .task { socket.getProfile(model.username) }
            .onChange(of: socket.connection) { _, state in
                if state == .connected { socket.getProfile(model.username) }
            }
        }
    }

    private var noticeBinding: Binding<Bool> {
        Binding(get: { socket.notice != nil }, set: { if !$0 { socket.notice = nil } })
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
                            onImage: { imageURL = IdentifiableURL(url: $0) }
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 90).id("bottom")
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
        case .disconnected:
            Label("Reconnecting", systemImage: "wifi.exclamationmark").font(.caption2).foregroundStyle(.orange)
        case .failed:
            Label("Offline", systemImage: "wifi.slash").font(.caption2).foregroundStyle(.red)
        }
    }

    private func isOwner(username: String) -> Bool {
        socket.users.contains { $0.isOwner && $0.username.caseInsensitiveCompare(username) == .orderedSame }
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

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
