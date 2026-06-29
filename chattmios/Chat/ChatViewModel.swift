import SwiftUI
import Observation

@Observable
@MainActor
final class ChatViewModel {
    let socket: SocketService
    let auth: AuthManager
    let settings: AppSettings

    var composerText = ""
    var pendingImage: PendingImage?
    var isUploading = false
    var uploadError: String?
    var focusRequest = false

    private var typingTask: Task<Void, Never>?
    private var isTyping = false

    init(socket: SocketService, auth: AuthManager, settings: AppSettings) {
        self.socket = socket
        self.auth = auth
        self.settings = settings
        socket.onNewMessage = { [weak self] message in
            guard let self else { return }
            // Notify + haptic when someone else @mentions you.
            guard message.username.caseInsensitiveCompare(self.username) != .orderedSame else { return }
            guard message.mentions(username: self.username) else { return }
            Haptics.warning()
            if !settings.notificationsMuted {
                NotificationManager.shared.notifyMention(from: message.username, text: message.text)
            }
        }
    }

    var username: String { auth.currentUsername ?? "guest" }
    var canModerate: Bool { socket.isOwner }

    func attachImage(data: Data, filename: String, mime: String) {
        pendingImage = PendingImage(data: data, filename: filename, mime: mime)
        uploadError = nil
    }

    func send() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || pendingImage != nil else { return }

        let caption = trimmed.isEmpty ? nil : trimmed
        let attachment = pendingImage
        composerText = ""
        pendingImage = nil
        stopTyping()

        if let attachment {
            Task { await upload(attachment, caption: caption) }
        } else if let caption {
            if caption.hasPrefix("/") {
                socket.sendCommand(caption, username: username)
            } else {
                socket.sendMessage(text: caption, username: username)
            }
            Haptics.tap()
        }
    }

    private func upload(_ image: PendingImage, caption: String?) async {
        guard let session = auth.session else { return }
        isUploading = true
        uploadError = nil
        defer { isUploading = false }
        do {
            let url = try await RESTClient.shared.upload(
                data: image.data, filename: image.filename, mimeType: image.mime,
                username: username, session: session, avatar: false)
            socket.sendMessage(text: caption, image: url, username: username)
            Haptics.success()
        } catch {
            uploadError = error.localizedDescription
            Haptics.warning()
        }
    }

    func delete(_ message: Message) {
        socket.deleteMessage(id: message.id)
    }

    // MARK: Typing

    func textChanged() {
        guard !composerText.isEmpty else { stopTyping(); return }
        if !isTyping {
            isTyping = true
            socket.setTyping(true)
        }
        typingTask?.cancel()
        typingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.stopTyping()
        }
    }

    private func stopTyping() {
        typingTask?.cancel()
        if isTyping {
            isTyping = false
            socket.setTyping(false)
        }
    }
}

struct PendingImage {
    let data: Data
    let filename: String
    let mime: String
    var preview: UIImage? { UIImage(data: data) }
}
