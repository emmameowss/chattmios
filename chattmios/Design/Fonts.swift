import SwiftUI
import CoreText

/// Registers bundled fonts (DM Mono — the typeface used by chattm.app) so they
/// can be referenced via `Font.custom`. Registering at runtime avoids needing
/// a UIAppFonts Info.plist entry.
enum AppFonts {
    private static var registered = false

    static func registerIfNeeded() {
        guard !registered else { return }
        registered = true
        for name in ["DMMono-Medium", "DMMono-Regular"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// The chattm.app wordmark font (DM Mono Medium).
    static func dmMono(_ size: CGFloat) -> Font {
        .custom("DMMono-Medium", size: size)
    }
}
