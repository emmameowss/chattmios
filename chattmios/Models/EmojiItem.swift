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
    let notes: String?
    let submittedAt: Date?
    let status: String?
    let reviewReason: String?

    var isPending: Bool { status == nil || status == "pending" }

    init?(dict: [String: Any]) {
        guard let shortcode = (dict["shortcode"] as? String) ?? (dict["name"] as? String),
              let url = dict["url"] as? String else { return nil }
        self.id = (dict["id"] as? String) ?? shortcode
        self.shortcode = shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        self.url = url
        self.submittedBy = (dict["submitter_username"] as? String)
            ?? (dict["submitter_email"] as? String)
            ?? (dict["submittedBy"] as? String)
            ?? (dict["email"] as? String)
        self.notes = dict["notes"] as? String
        if let ts = (dict["submitted_at"] as? Double)
            ?? (dict["submitted_at"] as? Int).map(Double.init) {
            self.submittedAt = Date(timeIntervalSince1970: ts / 1000)
        } else if let s = dict["submitted_at"] as? String,
                  let date = ISO8601DateFormatter().date(from: s) {
            self.submittedAt = date
        } else {
            self.submittedAt = nil
        }
        self.status = dict["status"] as? String
        self.reviewReason = dict["review_reason"] as? String
    }
}
