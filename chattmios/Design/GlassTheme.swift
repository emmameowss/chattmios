import SwiftUI

enum Brand {
    /// Pink accent matching chattm.app (light: #c95c7a, dark: #F5A9B8).
    static let accent = Color.dynamic(
        light: Color(hexString: "#c95c7a") ?? .pink,
        dark: Color(hexString: "#F5A9B8") ?? .pink)
    /// A slightly deeper pink for subtle two-tone fills.
    static let accentSecondary = Color.dynamic(
        light: Color(hexString: "#a84765") ?? .pink,
        dark: Color(hexString: "#ec7c9c") ?? .pink)

    /// App surfaces, mirroring the website's near-black / off-white palette.
    static let background = Color.dynamic(
        light: Color(hexString: "#f7f7f5") ?? .white,
        dark: Color(hexString: "#0e0e0e") ?? .black)
    static let surface = Color.dynamic(
        light: Color(hexString: "#eeede9") ?? .white,
        dark: Color(hexString: "#161616") ?? .black)

    static let danger = Color.dynamic(
        light: Color(hexString: "#b85555") ?? .red,
        dark: Color(hexString: "#d97a7a") ?? .red)

    /// Verified-badge blue, matching the site's verified.png.
    static let verified = Color(hexString: "#1d9bf0") ?? .blue

    /// Monochrome pink wash used for the wordmark / soft backgrounds.
    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    /// A color that resolves differently in light vs dark mode.
    static func dynamic(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}

/// A rounded card that uses Liquid Glass where available.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    /// `.navigationBarTitleDisplayMode(.inline)` on iOS; no-op on macOS.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// `.noAutocapitalization()` on iOS; no-op on macOS.
    func noAutocapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// Forces the view to fill all available space — needed on macOS where views size to content by default.
    func fillAvailableSpace() -> some View {
        #if os(macOS)
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        self
        #endif
    }

    /// Caps content to a readable max width on macOS and centers it in the available space.
    func macOSReadableWidth(_ max: CGFloat = 480) -> some View {
        #if os(macOS)
        self.frame(maxWidth: max).frame(maxWidth: .infinity)
        #else
        self
        #endif
    }

    /// Apply a glass background clipped to a rounded rect.
    func glassPanel(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        let effect: Glass = interactive ? .regular.interactive() : .regular
        return self.glassEffect(effect, in: .rect(cornerRadius: cornerRadius))
    }

    /// Capsule glass background, handy for floating controls.
    func glassCapsule(interactive: Bool = true) -> some View {
        let effect: Glass = interactive ? .regular.interactive() : .regular
        return self.glassEffect(effect, in: .capsule)
    }
}

extension Image {
    /// Cross-platform init from a platform image type.
    #if canImport(UIKit)
    init(platformImage: UIImage) { self.init(uiImage: platformImage) }
    #else
    init(platformImage: NSImage) { self.init(nsImage: platformImage) }
    #endif
}

extension ToolbarItemPlacement {
    /// Leading bar on iOS; `.automatic` on macOS.
    static var leadingBar: Self {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }
    /// Trailing bar on iOS; `.primaryAction` on macOS.
    static var trailingBar: Self {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}

/// Renders a username with its (possibly gradient) color.
struct ColoredName: View {
    let name: String
    let color: NameColor
    var font: Font = .subheadline.weight(.semibold)
    var fallback: Color = .primary

    var body: some View {
        Text(name)
            .font(font)
            .foregroundStyle(color.gradient(fallback: fallback))
    }
}
