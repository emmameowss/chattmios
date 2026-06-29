import SwiftUI

/// Renders message text with autolinked URLs, highlighted @mentions and inline
/// custom `:emoji:`. Tokenized by whitespace so emoji images can flow with words.
struct MessageBodyView: View {
    let text: String
    let emojiMap: [String: String]
    let mentionMe: Bool
    var font: Font = .body

    private enum Token: Identifiable {
        case word(String)
        case link(String, URL)
        case mention(String)
        case emoji(code: String, url: URL)
        var id: String {
            switch self {
            case .word(let w): return "w:\(w):\(UUID().uuidString)"
            case .link(let t, _): return "l:\(t):\(UUID().uuidString)"
            case .mention(let m): return "m:\(m):\(UUID().uuidString)"
            case .emoji(let c, _): return "e:\(c):\(UUID().uuidString)"
            }
        }
    }

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(tokens) { token in
                switch token {
                case .word(let word):
                    Text(word).font(font)
                case .link(let title, let url):
                    Link(title, destination: url)
                        .font(font)
                        .tint(Brand.accent)
                case .mention(let name):
                    Text(name)
                        .font(font.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Brand.accent.opacity(0.22), in: .rect(cornerRadius: 6))
                        .foregroundStyle(Brand.accent)
                case .emoji(_, let url):
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 22, height: 22)
                }
            }
        }
    }

    private var tokens: [Token] {
        var result: [Token] = []
        for raw in text.split(separator: " ", omittingEmptySubsequences: false) {
            let word = String(raw)
            if word.isEmpty { continue }
            // custom emoji  :code:
            if word.count > 2, word.hasPrefix(":"), word.hasSuffix(":") {
                let code = String(word.dropFirst().dropLast())
                if let urlStr = emojiMap[code], let url = URL(string: urlStr) {
                    result.append(.emoji(code: code, url: url))
                    continue
                }
            }
            // links
            if word.hasPrefix("http://") || word.hasPrefix("https://"),
               let url = URL(string: word) {
                result.append(.link(word, url))
                continue
            }
            // mentions
            if word.hasPrefix("@"), word.count > 1 {
                result.append(.mention(word))
                continue
            }
            result.append(.word(word))
        }
        return result
    }
}
