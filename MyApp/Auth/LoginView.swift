import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth

    @State private var guestUsername = ""
    @State private var showGuestField = false
    @State private var showWebAuth = false
    @State private var isWorking = false

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
                            showWebAuth = true
                        } label: {
                            Label("Continue with Hack Club", systemImage: "person.badge.key.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)

                        if showGuestField {
                            TextField("Guest name (optional)", text: $guestUsername)
                                .textInputAutocapitalization(.never)
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
                        .disabled(isWorking)
                    }
                }
                .padding(.horizontal, 28)

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
        .sheet(isPresented: $showWebAuth) {
            HCAWebAuthView { session in
                showWebAuth = false
                Task { await auth.completeWebAuth(session: session) }
            }
            .ignoresSafeArea()
        }
    }

    private func guestLogin() async {
        isWorking = true
        await auth.continueAsGuest(username: guestUsername.isEmpty ? nil : guestUsername)
        isWorking = false
    }
}
