import Foundation

/// Payload of the `profileData` event.
struct UserProfile: Equatable {
    var username: String
    var avatar: String?
    var pronouns: String
    var bio: String
    var status: PresenceStatus
    var verified: Bool
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
        self.verified = (dict["verified"] as? Bool) ?? false
        self.isOwner = (dict["isOwner"] as? Bool) ?? false
        self.isGuest = (dict["isGuest"] as? Bool) ?? false
        self.online = (dict["online"] as? Bool) ?? false
        if let ls = dict["lastSeen"], !(ls is NSNull) {
            self.lastSeen = Message.parseTime(ls)
        }
        self.color = dict["color"] as? String
        self.email = dict["email"] as? String
    }
}
