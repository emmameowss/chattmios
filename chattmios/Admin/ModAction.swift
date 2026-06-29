import Foundation

/// A parameterized moderation command rendered as a small form.
enum ModAction: String, Identifiable, CaseIterable {
    case ban, unban, kick, mute, unmute, whois
    case verify, unverify, setColor, setNick, resetStrikes
    case announce, status, maintenance
    case addFilter, removeFilter
    case addEmoji, removeEmoji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ban: return "Ban user"
        case .unban: return "Unban (email)"
        case .kick: return "Kick user"
        case .mute: return "Mute user"
        case .unmute: return "Unmute user"
        case .whois: return "Whois"
        case .verify: return "Verify (email)"
        case .unverify: return "Unverify (email)"
        case .setColor: return "Set user color"
        case .setNick: return "Rename user"
        case .resetStrikes: return "Reset strikes"
        case .announce: return "Announce"
        case .status: return "Set status notice"
        case .maintenance: return "Maintenance mode"
        case .addFilter: return "Add filtered word"
        case .removeFilter: return "Remove filtered word"
        case .addEmoji: return "Add emoji"
        case .removeEmoji: return "Remove emoji"
        }
    }

    var icon: String {
        switch self {
        case .ban: return "hammer"
        case .unban: return "hand.raised.slash"
        case .kick: return "figure.walk.departure"
        case .mute: return "mic.slash"
        case .unmute: return "mic"
        case .whois: return "magnifyingglass"
        case .verify: return "checkmark.seal"
        case .unverify: return "seal"
        case .setColor: return "paintpalette"
        case .setNick: return "pencil"
        case .resetStrikes: return "arrow.counterclockwise"
        case .announce: return "megaphone"
        case .status: return "text.bubble"
        case .maintenance: return "wrench.and.screwdriver"
        case .addFilter: return "plus.circle"
        case .removeFilter: return "minus.circle"
        case .addEmoji: return "face.smiling"
        case .removeEmoji: return "face.dashed"
        }
    }

    var destructive: Bool {
        switch self {
        case .ban, .kick, .maintenance: return true
        default: return false
        }
    }

    var command: String {
        switch self {
        case .ban: return "/ban"; case .unban: return "/unban"; case .kick: return "/kick"
        case .mute: return "/mute"; case .unmute: return "/unmute"; case .whois: return "/whois"
        case .verify: return "/verify"; case .unverify: return "/unverify"
        case .setColor: return "/setcolor"; case .setNick: return "/setnick"
        case .resetStrikes: return "/resetstrikes"
        case .announce: return "/announce"; case .status: return "/status"
        case .maintenance: return "/maintenance"
        case .addFilter: return "/addfilter"; case .removeFilter: return "/removefilter"
        case .addEmoji: return "/addemoji"; case .removeEmoji: return "/removeemoji"
        }
    }

    /// Labelled input fields for this action.
    var fields: [Field] {
        switch self {
        case .ban: return [.init(key: "username", placeholder: "Username", required: true), .init(key: "reason", placeholder: "Reason (optional)")]
        case .unban, .verify, .unverify: return [.init(key: "email", placeholder: "Email", required: true)]
        case .kick: return [.init(key: "username", placeholder: "Username", required: true), .init(key: "reason", placeholder: "Reason (optional)")]
        case .mute: return [.init(key: "username", placeholder: "Username", required: true), .init(key: "time", placeholder: "Duration (e.g. 10m, 2h)", required: true), .init(key: "reason", placeholder: "Reason (optional)")]
        case .unmute, .whois, .resetStrikes: return [.init(key: "username", placeholder: "Username", required: true)]
        case .setColor: return [.init(key: "username", placeholder: "Username", required: true), .init(key: "color", placeholder: "hex or flag", required: true)]
        case .setNick: return [.init(key: "old", placeholder: "Current name", required: true), .init(key: "new", placeholder: "New name", required: true)]
        case .announce, .status: return [.init(key: "text", placeholder: "Message", required: true)]
        case .maintenance: return [.init(key: "reason", placeholder: "Reason (optional)")]
        case .addFilter, .removeFilter: return [.init(key: "word", placeholder: "Word", required: true)]
        case .addEmoji: return [.init(key: "code", placeholder: ":shortcode:", required: true), .init(key: "url", placeholder: "Image URL", required: true)]
        case .removeEmoji: return [.init(key: "code", placeholder: ":shortcode:", required: true)]
        }
    }

    struct Field: Identifiable {
        let key: String
        let placeholder: String
        var required: Bool = false
        var id: String { key }
    }
}
