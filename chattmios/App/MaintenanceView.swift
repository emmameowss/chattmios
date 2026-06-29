import SwiftUI

struct MaintenanceView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("chat™")
                    .font(.dmMono(44))
                    .foregroundStyle(Brand.gradient)
                GlassCard {
                    VStack(spacing: 12) {
                        Label("Under Maintenance", systemImage: "wrench.and.screwdriver.fill")
                            .font(.headline)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                Button("Try Again", action: onRetry)
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 28)
                Spacer()
            }
        }
    }
}
