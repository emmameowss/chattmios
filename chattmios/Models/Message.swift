import Foundation

/// A chat message as broadcast by the chattm server.
struct Message: Identifiable, Equatable {
    let id: String
    var ownerEmail: String?
    var username: String
    var text: String?
    var time: Date
    var isToken: Bool       // sent by an authenticated (HCA) account
    var isGuest: Bool
    var color: String?      // raw color string ("#hex" or "flag:name")
    var avatar: String?     // avatar URL
    var verified: Bool
    var mentions: [String]
    var image: String?      // attached image/file URL
    var system: Bool        // server/system announcement

    var nameColor: NameColor { NameColor(raw: color) }

    /// Whether this row carries any displayable body (text or image).
    var hasBody: Bool {
        (text?.isEmpty == false) || (image != nil)
    }

    init(id: String,
         username: String,
         text: String?,
         time: Date,
         ownerEmail: String? = nil,
         isToken: Bool = false,
         isGuest: Bool = false,
         color: String? = nil,
         avatar: String? = nil,
         verified: Bool = false,
         mentions: [String] = [],
         image: String? = nil,
         system: Bool = false) {
        self.id = id
        self.username = username
        self.text = text
        self.time = time
        self.ownerEmail = ownerEmail
        self.isToken = isToken
        self.isGuest = isGuest
        self.color = color
        self.avatar = avatar
        self.verified = verified
        self.mentions = mentions
        self.image = image
        self.system = system
    }

    init?(dict: [String: Any]) {
        // System messages may lack username; fall back gracefully.
        guard let id = dict["id"] as? String else { return nil }
        self.id = id
        self.username = (dict["username"] as? String) ?? "system"
        self.text = dict["text"] as? String
        self.time = Message.parseTime(dict["time"])
        self.ownerEmail = dict["ownerEmail"] as? String
        self.isToken = (dict["isToken"] as? Bool) ?? false
        self.isGuest = (dict["isGuest"] as? Bool) ?? false
        self.color = dict["color"] as? String
        self.avatar = dict["avatar"] as? String
        self.verified = (dict["verified"] as? Bool) ?? false
        self.mentions = (dict["mentions"] as? [String]) ?? []
        self.image = dict["image"] as? String
        self.system = (dict["system"] as? Bool) ?? (dict["isSystem"] as? Bool) ?? false
    }

    /// Server `time` may arrive as epoch milliseconds (number) or an ISO string.
    static func parseTime(_ value: Any?) -> Date {
        if let ms = value as? Double { return Date(timeIntervalSince1970: ms / 1000) }
        if let ms = value as? Int { return Date(timeIntervalSince1970: Double(ms) / 1000) }
        if let str = value as? String {
            if let ms = Double(str) { return Date(timeIntervalSince1970: ms / 1000) }
            let fmt = ISO8601DateFormatter()
            if let date = fmt.date(from: str) { return date }
        }
        return Date()
    }

    /// Returns true if this message @mentions the given username (case-insensitive).
    func mentions(username: String?) -> Bool {
        guard let username, !username.isEmpty else { return false }
        if mentions.contains(where: { $0.caseInsensitiveCompare(username) == .orderedSame }) {
            return true
        }
        guard let text else { return false }
        return text.range(of: "@\(username)", options: .caseInsensitive) != nil
    }
}
