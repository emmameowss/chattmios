import Foundation

enum PresenceStatus: String {
    case online, idle, dnd, offline

    var label: String {
        switch self {
        case .online: return "Online"
        case .idle: return "Idle"
        case .dnd: return "Do Not Disturb"
        case .offline: return "Offline"
        }
    }
}

/// An entry in the `userlist` event.
struct ChatUserSummary: Identifiable, Equatable {
    var username: String
    var status: PresenceStatus
    var online: Bool
    var isOwner: Bool
    var isGuest: Bool
    var verified: Bool
    var redVerified: Bool
    var color: String?
    var avatar: String?
    var lastSeen: Date?

    var id: String { username }
    var nameColor: NameColor { NameColor(raw: color) }

    var effectiveStatus: PresenceStatus { online ? status : .offline }

    init?(dict: [String: Any]) {
        guard let username = dict["username"] as? String else { return nil }
        self.username = username
        let online = Self.parseBool(dict["online"]) ?? true
        self.online = online
        if let raw = dict["status"] as? String, let s = PresenceStatus(rawValue: raw) {
            self.status = s
        } else {
            self.status = online ? .online : .offline
        }
        self.isOwner = Self.parseBool(dict["isOwner"]) ?? Self.parseBool(dict["owner"]) ?? false
        self.isGuest = Self.parseBool(dict["isGuest"]) ?? Self.parseBool(dict["guest"]) ?? false
        self.verified = Self.parseBool(dict["verified"]) ?? false
        self.redVerified = Self.parseBool(dict["redVerified"]) ?? false
        self.color = dict["color"] as? String
        self.avatar = dict["avatar"] as? String
        if let ls = dict["lastSeen"] {
            self.lastSeen = Message.parseTime(ls)
        }
    }

    /// Handles JSON booleans AND integer 0/1 from SQLite-backed servers.
    static func parseBool(_ value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? Int { return n != 0 }
        if let n = value as? Double { return n != 0 }
        if value is NSNull { return nil }
        return nil
    }
}
