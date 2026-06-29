import SwiftUI

/// Represents a username color, which on chattm can be either a hex color
/// (e.g. "#ff8800") or a pride flag gradient (encoded server-side as "flag:<name>").
enum NameColor: Equatable {
    case none
    case solid(Color)
    case flag(PrideFlag)

    /// Parse the `color` field that arrives on messages / profiles.
    init(raw: String?) {
        guard let raw, !raw.isEmpty else { self = .none; return }
        let value = raw.lowercased()
        if value.hasPrefix("flag:") {
            let name = String(value.dropFirst("flag:".count))
            if let flag = PrideFlag(rawValue: name) { self = .flag(flag); return }
            self = .none
            return
        }
        if let color = Color(hexString: raw) {
            self = .solid(color)
            return
        }
        // Some flags are stored as bare names (e.g. "pride").
        if let flag = PrideFlag(rawValue: value) { self = .flag(flag); return }
        self = .none
    }

    /// A gradient suitable for masking text. Solid colors become a single-stop gradient.
    func gradient(fallback: Color) -> LinearGradient {
        switch self {
        case .none:
            return LinearGradient(colors: [fallback], startPoint: .leading, endPoint: .trailing)
        case .solid(let color):
            return LinearGradient(colors: [color], startPoint: .leading, endPoint: .trailing)
        case .flag(let flag):
            return LinearGradient(colors: flag.colors, startPoint: .leading, endPoint: .trailing)
        }
    }

    var isFlag: Bool { if case .flag = self { return true }; return false }
}

enum PrideFlag: String, CaseIterable, Identifiable {
    case pride, trans, bi, lesbian, nb, pan, ace, gay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pride: return "Pride"
        case .trans: return "Trans"
        case .bi: return "Bisexual"
        case .lesbian: return "Lesbian"
        case .nb: return "Non-binary"
        case .pan: return "Pansexual"
        case .ace: return "Asexual"
        case .gay: return "Gay"
        }
    }

    var colors: [Color] {
        switch self {
        case .pride:
            return ["#e40303", "#ff8c00", "#ffed00", "#008026", "#004dff", "#750787"].compactMap { Color(hexString: $0) }
        case .trans:
            return ["#5bcefa", "#f5a9b8", "#ffffff", "#f5a9b8", "#5bcefa"].compactMap { Color(hexString: $0) }
        case .bi:
            return ["#d60270", "#9b4f96", "#0038a8"].compactMap { Color(hexString: $0) }
        case .lesbian:
            return ["#d52d00", "#ff9a56", "#ffffff", "#d362a4", "#a30262"].compactMap { Color(hexString: $0) }
        case .nb:
            return ["#fcf434", "#ffffff", "#9c59d1", "#2c2c2c"].compactMap { Color(hexString: $0) }
        case .pan:
            return ["#ff218c", "#ffd800", "#21b1ff"].compactMap { Color(hexString: $0) }
        case .ace:
            return ["#000000", "#a3a3a3", "#ffffff", "#800080"].compactMap { Color(hexString: $0) }
        case .gay:
            return ["#078d70", "#98e8c1", "#ffffff", "#7bade2", "#3d1a78"].compactMap { Color(hexString: $0) }
        }
    }
}

extension Color {
    /// Initialize from a "#rrggbb" / "rrggbb" / "#rgb" hex string.
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 3 else { return nil }
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }

    /// Deterministic color derived from a string (used for avatar placeholders).
    static func deterministic(from string: String) -> Color {
        var hash: UInt64 = 5381
        for byte in string.utf8 { hash = (hash &* 33) ^ UInt64(byte) }
        let hue = Double(hash % 360) / 360
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }
}
