import SwiftUI
import Observation

@Observable
@MainActor
final class ChatViewModel {
    let socket: SocketService
    let auth: AuthManager
    let settings: AppSettings

    var composerText = ""
    var isUploading = false
    var uploadError: String?

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

    func send() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        composerText = ""
        stopTyping()
        if trimmed.hasPrefix("/") {
            socket.sendCommand(trimmed, username: username)
        } else {
            socket.sendMessage(text: trimmed, username: username)
        }
        Haptics.tap()
    }

    func sendImage(data: Data, filename: String, mime: String) async {
        guard let session = auth.session else { return }
        isUploading = true
        uploadError = nil
        defer { isUploading = false }
        do {
            let url = try await RESTClient.shared.upload(
                data: data, filename: filename, mimeType: mime,
                username: username, session: session, avatar: false)
            let caption = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
            socket.sendMessage(text: caption.isEmpty ? nil : caption, image: url, username: username)
            composerText = ""
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
