import SwiftUI
import ClerkKit
import ClerkKitUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(Clerk.self) private var clerk

    @State private var guestUsername = ""
    @State private var showGuestField = false
    @State private var showAuth = false
    @State private var isWorking = false
    @State private var guestsDisabled = false

    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("chat™")
                    .font(.dmMono(54))
                    .foregroundStyle(Brand.gradient)

                Spacer()

                GlassEffectContainer(spacing: 14) {
                    VStack(spacing: 14) {
                        Button {
                            showAuth = true
                        } label: {
                            Label("Sign in or Create account", systemImage: "person.crop.circle.badge.checkmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isWorking)

                        if showGuestField && !guestsDisabled {
                            TextField("Guest name (optional)", text: $guestUsername)
                                .noAutocapitalization()
                                .autocorrectionDisabled()
                                .padding()
                                .glassPanel(cornerRadius: 16)
                        }

                        Button {
                            if showGuestField {
                                Task { await guestLogin() }
                            } else {
                                withAnimation { showGuestField = true }
                            }
                        } label: {
                            Label(showGuestField ? "Enter as Guest" : "Continue as Guest",
                                  systemImage: "person.fill.questionmark")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glass)
                        .disabled(isWorking || guestsDisabled)

                        if guestsDisabled {
                            Text("Guest sign-in is currently disabled.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .macOSReadableWidth()

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if isWorking { ProgressView() }

                Spacer()
                Text("By continuing you agree to the chattm.app terms & privacy policy.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)
            }
        }
        .task {
            if let info = try? await RESTClient.shared.maintenance() {
                guestsDisabled = info.guestsDisabled
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthView()
        }
        .onChange(of: clerk.user?.id) { _, userID in
            // Clerk finished signing the user in → exchange their session JWT
            // for one of our own app sessions. Only when fully signed out on
            // our side (avoids re-exchanging on an already-signed-in launch).
            guard userID != nil, auth.state == .signedOut, !isWorking else { return }
            showAuth = false
            Task {
                isWorking = true
                await auth.completeClerkLogin()
                isWorking = false
            }
        }
    }

    private func guestLogin() async {
        isWorking = true
        await auth.continueAsGuest(username: guestUsername.isEmpty ? nil : guestUsername)
        isWorking = false
    }
}
