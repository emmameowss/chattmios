import Foundation
import Observation
import SocketIO

/// Live connection to the chattm Socket.IO server.
@Observable
@MainActor
final class SocketService {
    enum ConnectionState: Equatable {
        case idle, connecting, connected, disconnected
        case failed(String)
    }

    // Published state
    private(set) var connection: ConnectionState = .idle
    private(set) var messages: [Message] = []
    private(set) var users: [ChatUserSummary] = []
    private(set) var emojiMap: [String: String] = [:]
    private(set) var profiles: [String: UserProfile] = [:]
    private(set) var typingUsers: Set<String> = []
    private(set) var isOwner = false
    private(set) var chatMuted = false
    private(set) var guestsAllowed = true

    /// Set when the server forcibly ends the session (ban/kick).
    var disconnectNotice: String?
    /// Set when the server goes into maintenance mode (session remains valid).
    private(set) var maintenanceNotice: String?
    /// Transient moderation notices (muted/unmuted, etc.).
    var notice: String?
    /// Most recently received new message id (used to trigger sound/scroll).
    private(set) var lastIncomingID: String?

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var session: String?
    private var typingExpiry: [String: Date] = [:]

    var onNewMessage: ((Message) -> Void)?

    // MARK: Lifecycle

    func connect(session: String) {
        guard self.socket == nil else { return }
        self.session = session
        connection = .connecting

        let manager = SocketManager(socketURL: Server.baseURL, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .reconnectWait(2),
            .extraHeaders(["Origin": Server.origin]),
        ])
        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket
        registerHandlers(socket)
        socket.connect(withPayload: ["session": session])
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        connection = .idle
    }

    func reconnect() {
        guard let session else { return }
        socket?.disconnect()
        socket = nil
        manager = nil
        connect(session: session)
    }

    // MARK: Handlers

    private func registerHandlers(_ socket: SocketIOClient) {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self else { return }
            self.connection = .connected
            self.maintenanceNotice = nil
            socket.emit("userActive")
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            self?.connection = .disconnected
        }
        socket.on(clientEvent: .error) { [weak self] data, _ in
            guard let self else { return }
            let reason = (data.first as? String) ?? "Connection error"
            self.connection = .failed(reason)
        }

        socket.on("history") { [weak self] data, _ in
            guard let self, let raw = data.first else { return }
            let dicts = Self.dictArray(raw)
            let parsed = dicts.compactMap(Message.init(dict:))
            self.messages = parsed.sorted { $0.time < $1.time }
        }

        socket.on("message") { [weak self] data, _ in
            guard let self, let dict = data.first as? [String: Any],
                  let msg = Message(dict: dict) else { return }
            self.appendMessage(msg)
        }

        socket.on("messageDeleted") { [weak self] data, _ in
            guard let self else { return }
            let id = (data.first as? String) ?? (data.first as? [String: Any])?["id"] as? String
            if let id { self.messages.removeAll { $0.id == id } }
        }

        socket.on("userlist") { [weak self] data, _ in
            guard let self, let raw = data.first else { return }
            self.users = Self.parseUserlist(raw)
        }

        socket.on("init") { [weak self] data, _ in
            guard let self, let dict = data.first as? [String: Any] else { return }
            self.isOwner = (dict["isOwner"] as? Bool) ?? (dict["owner"] as? Bool) ?? false
            self.chatMuted = (dict["chatMuted"] as? Bool) ?? (dict["mutechat"] as? Bool) ?? false
            if let guests = dict["guestsAllowed"] as? Bool { self.guestsAllowed = guests }
            else if let noguests = dict["noguests"] as? Bool { self.guestsAllowed = !noguests }
        }

        let emojiHandler: ([Any], SocketAckEmitter) -> Void = { [weak self] data, _ in
            guard let self, let raw = data.first else { return }
            self.emojiMap = Self.parseEmoji(raw)
        }
        socket.on("emoji", callback: emojiHandler)
        socket.on("emojiUpdate", callback: emojiHandler)

        socket.on("profileData") { [weak self] data, _ in
            guard let self, let dict = data.first as? [String: Any],
                  let profile = UserProfile(dict: dict) else { return }
            self.profiles[profile.username] = profile
        }

        // Typing indicators (best-effort: server may send username string or dict)
        socket.on("typing") { [weak self] data, _ in
            guard let self, let name = Self.username(from: data.first) else { return }
            self.typingUsers.insert(name)
            self.typingExpiry[name] = Date().addingTimeInterval(6)
            self.pruneTyping()
        }
        socket.on("stopTyping") { [weak self] data, _ in
            guard let self, let name = Self.username(from: data.first) else { return }
            self.typingUsers.remove(name)
            self.typingExpiry[name] = nil
        }

        // Moderation / chat control
        socket.on("mutechat") { [weak self] _, _ in self?.chatMuted = true; self?.notice = "Chat has been muted." }
        socket.on("unmutechat") { [weak self] _, _ in self?.chatMuted = false; self?.notice = "Chat has been unmuted." }
        socket.on("muted") { [weak self] data, _ in
            self?.notice = Self.reason(from: data.first) ?? "You have been muted."
        }
        socket.on("unmuted") { [weak self] _, _ in self?.notice = "You have been unmuted." }

        // Forced disconnects
        socket.on("banned") { [weak self] data, _ in
            self?.disconnectNotice = Self.reason(from: data.first).map { "Banned: \($0)" } ?? "You have been banned."
        }
        socket.on("kicked") { [weak self] data, _ in
            self?.disconnectNotice = Self.reason(from: data.first).map { "Kicked: \($0)" } ?? "You have been kicked."
        }
        socket.on("maintenance") { [weak self] data, _ in
            self?.maintenanceNotice = Self.reason(from: data.first) ?? "The server is under maintenance."
        }
    }

    private func appendMessage(_ msg: Message) {
        if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
            messages[idx] = msg
        } else {
            messages.append(msg)
            lastIncomingID = msg.id
            onNewMessage?(msg)
        }
        typingUsers.remove(msg.username)
    }

    private func pruneTyping() {
        let now = Date()
        for (name, expiry) in typingExpiry where expiry < now {
            typingUsers.remove(name)
            typingExpiry[name] = nil
        }
    }

    // MARK: Emit

    func sendMessage(text: String?, image: String? = nil, username: String) {
        var payload: [String: Any] = ["username": username]
        payload["text"] = text ?? NSNull()
        payload["image"] = image ?? NSNull()
        socket?.emit("message", payload)
    }

    /// Send a slash command (delivered as ordinary message text).
    func sendCommand(_ text: String, username: String) {
        socket?.emit("message", ["username": username, "text": text, "image": NSNull()])
    }

    func setTyping(_ typing: Bool) {
        socket?.emit(typing ? "typing" : "stopTyping")
    }

    func deleteMessage(id: String) { socket?.emit("deleteMessage", id) }
    func setUsername(_ name: String) { socket?.emit("setUsername", name) }
    func setBio(_ bio: String) { socket?.emit("setBio", bio) }
    func setPronouns(_ pronouns: String) { socket?.emit("setPronouns", pronouns) }
    func setStatus(_ status: PresenceStatus) { socket?.emit("setStatus", status.rawValue) }
    func setAvatar(_ url: String) { socket?.emit("setAvatar", url) }
    func deleteAvatar() { socket?.emit("deleteAvatar") }
    func getProfile(_ username: String) { socket?.emit("getProfile", username) }

    // MARK: Parsing helpers

    private static func dictArray(_ raw: Any) -> [[String: Any]] {
        if let arr = raw as? [[String: Any]] { return arr }
        if let arr = raw as? [Any] { return arr.compactMap { $0 as? [String: Any] } }
        return []
    }

    private static func parseUserlist(_ raw: Any) -> [ChatUserSummary] {
        // Flat array of user objects (the server's actual shape).
        if let arr = raw as? [Any] {
            return arr.compactMap { element in
                if let dict = element as? [String: Any] { return ChatUserSummary(dict: dict) }
                if let name = element as? String { return ChatUserSummary(dict: ["username": name]) }
                return nil
            }
        }
        // Object with online/offline/users buckets (defensive).
        if let dict = raw as? [String: Any] {
            var result: [ChatUserSummary] = []
            for key in ["online", "offline", "users"] {
                if let arr = dict[key] as? [Any] {
                    result += arr.compactMap { element -> ChatUserSummary? in
                        guard var d = element as? [String: Any] else { return nil }
                        if key == "offline" { d["online"] = false }
                        return ChatUserSummary(dict: d)
                    }
                }
            }
            return result
        }
        return []
    }

    private static func parseEmoji(_ raw: Any) -> [String: String] {
        // The server keys shortcodes with surrounding colons (":3:"); normalize to bare ("3").
        func code(_ raw: String) -> String {
            raw.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        }
        var map: [String: String] = [:]
        if let dict = raw as? [String: Any] {
            for (key, value) in dict {
                if let url = (value as? String) ?? ((value as? [String: Any])?["url"] as? String) {
                    map[code(key)] = url
                }
            }
            return map
        }
        if let arr = raw as? [[String: Any]] {
            for item in arr {
                if let shortcode = (item["shortcode"] as? String) ?? (item["name"] as? String),
                   let url = item["url"] as? String {
                    map[code(shortcode)] = url
                }
            }
            return map
        }
        return map
    }

    private static func username(from raw: Any?) -> String? {
        if let s = raw as? String { return s }
        if let d = raw as? [String: Any] { return d["username"] as? String }
        return nil
    }

    private static func reason(from raw: Any?) -> String? {
        if let s = raw as? String, !s.isEmpty { return s }
        if let d = raw as? [String: Any] { return d["reason"] as? String }
        return nil
    }
}
