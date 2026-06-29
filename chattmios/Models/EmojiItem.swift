import Foundation

/// A custom emoji: `:shortcode:` mapped to an image URL.
struct EmojiItem: Identifiable, Equatable {
    let shortcode: String   // without surrounding colons
    let url: String
    var id: String { shortcode }
}

/// A pending custom-emoji suggestion awaiting owner review.
struct PendingEmoji: Identifiable, Equatable {
    let id: String
    let shortcode: String
    let url: String
    let submittedBy: String?

    init?(dict: [String: Any]) {
        guard let shortcode = (dict["shortcode"] as? String) ?? (dict["name"] as? String),
              let url = dict["url"] as? String else { return nil }
        self.id = (dict["id"] as? String) ?? shortcode
        self.shortcode = shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        self.url = url
        self.submittedBy = (dict["submittedBy"] as? String) ?? (dict["email"] as? String)
    }
}
