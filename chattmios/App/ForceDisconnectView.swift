import SwiftUI

struct BannedView: View {
    let message: String
    let onReconnect: () -> Void
    let onSignOut: () -> Void

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
                        Label("You've been banned", systemImage: "person.slash.fill")
                            .font(.headline)
                            .foregroundStyle(Brand.danger)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                VStack(spacing: 12) {
                    Button("Reconnect", action: onReconnect)
                        .buttonStyle(.glassProminent)
                    Button("Sign Out", action: onSignOut)
                        .buttonStyle(.glass)
                }
                .padding(.horizontal, 28)
                Spacer()
            }
        }
    }
}

struct KickedView: View {
    let message: String
    let onReconnect: () -> Void

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
                        Label("You've been kicked", systemImage: "figure.walk.departure")
                            .font(.headline)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                Button("Reconnect", action: onReconnect)
                    .buttonStyle(.glassProminent)
                    .padding(.horizontal, 28)
                Spacer()
            }
        }
    }
}
