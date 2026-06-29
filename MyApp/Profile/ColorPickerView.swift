import SwiftUI

/// Pick a name color: a custom hex, or one of the pride flag gradients.
/// Calls `onSelect` with the command-ready value ("#rrggbb" or a flag name).
struct NameColorPicker: View {
    let current: String?
    var onSelect: (String) -> Void

    @State private var customColor: Color = Brand.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom Color").font(.caption).foregroundStyle(.secondary)
            HStack {
                ColorPicker("Pick a color", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                Text(customColor.hexString)
                    .font(.system(.subheadline, design: .monospaced))
                Spacer()
                Button("Apply") { onSelect(customColor.hexString) }
                    .buttonStyle(.glass)
            }

            Text("Pride Flags").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(PrideFlag.allCases) { flag in
                    Button { onSelect(flag.rawValue) } label: {
                        Text(flag.displayName)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: flag.colors, startPoint: .leading, endPoint: .trailing),
                                in: .rect(cornerRadius: 12))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension Color {
    /// Best-effort "#rrggbb" representation.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
