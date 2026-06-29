import SwiftUI

struct TypingIndicatorView: View {
    let names: [String]
    @State private var phase = 0.0

    private var label: String {
        switch names.count {
        case 0: return ""
        case 1: return "\(names[0]) is typing"
        case 2: return "\(names[0]) and \(names[1]) are typing"
        default: return "\(names.count) people are typing"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(.secondary)
                        .opacity(dotOpacity(i))
                }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }

    private func dotOpacity(_ index: Int) -> Double {
        let p = (phase + Double(index)).truncatingRemainder(dividingBy: 3)
        return 0.3 + 0.7 * (1 - abs(p - 1.5) / 1.5)
    }
}
