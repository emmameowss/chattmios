import Foundation

/// Payload of the `profileData` event.
struct UserProfile: Equatable {
    var username: String
    var avatar: String?
    var pronouns: String
    var bio: String
    var status: PresenceStatus
    var verified: Bool
    var redVerified: Bool
    var isOwner: Bool
    var isGuest: Bool
    var online: Bool
    var lastSeen: Date?
    var color: String?
    var email: String?

    var nameColor: NameColor { NameColor(raw: color) }

    init?(dict: [String: Any]) {
        guard let username = dict["username"] as? String else { return nil }
        self.username = username
        self.avatar = dict["avatar"] as? String
        self.pronouns = (dict["pronouns"] as? String) ?? ""
        self.bio = (dict["bio"] as? String) ?? ""
        if let raw = dict["status"] as? String, let s = PresenceStatus(rawValue: raw) {
            self.status = s
        } else {
            self.status = .offline
        }
        self.verified = ChatUserSummary.parseBool(dict["verified"]) ?? false
        self.redVerified = ChatUserSummary.parseBool(dict["redVerified"]) ?? false
        self.isOwner = ChatUserSummary.parseBool(dict["isOwner"]) ?? false
        self.isGuest = ChatUserSummary.parseBool(dict["isGuest"]) ?? false
        self.online = ChatUserSummary.parseBool(dict["online"]) ?? false
        if let ls = dict["lastSeen"], !(ls is NSNull) {
            self.lastSeen = Message.parseTime(ls)
        }
        self.color = dict["color"] as? String
        self.email = dict["email"] as? String
    }
}
