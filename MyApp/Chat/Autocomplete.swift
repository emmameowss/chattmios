import Foundation

/// Computes inline autocomplete suggestions for the composer.
enum Autocomplete {
    enum Suggestion: Identifiable, Equatable {
        case command(SlashCommand)
        case mention(String)
        case emoji(code: String, url: String)

        var id: String {
            switch self {
            case .command(let c): return "c:\(c.name)"
            case .mention(let m): return "m:\(m)"
            case .emoji(let code, _): return "e:\(code)"
            }
        }
        var insertion: String {
            switch self {
            case .command(let c): return c.name + " "
            case .mention(let m): return "@\(m) "
            case .emoji(let code, _): return ":\(code): "
            }
        }
    }

    /// The token currently being typed (substring after the last whitespace).
    static func currentToken(_ text: String) -> String {
        guard let lastSpace = text.lastIndex(where: { $0 == " " || $0 == "\n" }) else { return text }
        return String(text[text.index(after: lastSpace)...])
    }

    static func suggestions(for text: String, users: [String], emoji: [String: String], isOwner: Bool) -> [Suggestion] {
        let token = currentToken(text)
        guard !token.isEmpty else { return [] }

        // Commands only at the very start of the message.
        if token.hasPrefix("/"), text == token {
            return SlashCommand.matching(prefix: token, isOwner: isOwner)
                .prefix(6).map { .command($0) }
        }
        if token.hasPrefix("@"), token.count >= 1 {
            let q = token.dropFirst().lowercased()
            return users
                .filter { q.isEmpty || $0.lowercased().hasPrefix(q) }
                .prefix(6)
                .map { .mention($0) }
        }
        if token.hasPrefix(":"), token.count >= 2 {
            let q = token.dropFirst().lowercased()
            return emoji
                .filter { $0.key.lowercased().hasPrefix(q) }
                .sorted { $0.key < $1.key }
                .prefix(8)
                .map { .emoji(code: $0.key, url: $0.value) }
        }
        return []
    }

    /// Replace the current token in `text` with the suggestion's insertion.
    static func apply(_ suggestion: Suggestion, to text: String) -> String {
        let token = currentToken(text)
        return String(text.dropLast(token.count)) + suggestion.insertion
    }
}
