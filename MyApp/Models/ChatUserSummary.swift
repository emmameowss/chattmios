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
    var color: String?
    var avatar: String?
    var lastSeen: Date?

    var id: String { username }
    var nameColor: NameColor { NameColor(raw: color) }

    var effectiveStatus: PresenceStatus { online ? status : .offline }

    init?(dict: [String: Any]) {
        guard let username = dict["username"] as? String else { return nil }
        self.username = username
        let online = (dict["online"] as? Bool) ?? true
        self.online = online
        if let raw = dict["status"] as? String, let s = PresenceStatus(rawValue: raw) {
            self.status = s
        } else {
            self.status = online ? .online : .offline
        }
        self.isOwner = (dict["isOwner"] as? Bool) ?? (dict["owner"] as? Bool) ?? false
        self.isGuest = (dict["isGuest"] as? Bool) ?? (dict["guest"] as? Bool) ?? false
        self.verified = (dict["verified"] as? Bool) ?? false
        self.color = dict["color"] as? String
        self.avatar = dict["avatar"] as? String
        if let ls = dict["lastSeen"] {
            self.lastSeen = Message.parseTime(ls)
        }
    }
}
