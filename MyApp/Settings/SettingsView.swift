import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AuthManager.self) private var auth

    @State private var stats: ServerStats?
    @State private var version: VersionInfo?
    @State private var showSignOutConfirm = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Toggle("Notify me on mentions", isOn: Binding(
                        get: { !settings.notificationsMuted },
                        set: { settings.notificationsMuted = !$0 }))
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get a notification when someone @mentions you in chat.")
                }

                Section("Server") {
                    if let stats {
                        LabeledContent("Users", value: stats.users.map(String.init) ?? "—")
                        LabeledContent("Messages", value: stats.messages.map(String.init) ?? "—")
                        LabeledContent("Custom emoji", value: stats.emoji.map(String.init) ?? "—")
                        if let size = stats.formattedSize {
                            LabeledContent("Storage used", value: size)
                        }
                    } else {
                        HStack { Text("Stats"); Spacer(); ProgressView() }
                    }
                    if let commit = version?.commit {
                        LabeledContent("Server build", value: String(commit.prefix(7)))
                    }
                }

                Section("About") {
                    Link(destination: Server.url("privacy")) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: Server.baseURL) {
                        Label("chattm.app", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://github.com/emmameowss/chattm")!) {
                        Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    LabeledContent("App version", value: appVersion)
                }

                Section {
                    HStack {
                        Text("Signed in as")
                        Spacer()
                        Text(auth.currentUsername ?? "guest").foregroundStyle(.secondary)
                        if auth.isGuest {
                            Text("guest").font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.gray.opacity(0.3), in: .capsule)
                        }
                    }
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                stats = try? await RESTClient.shared.stats()
                version = try? await RESTClient.shared.version()
            }
            .alert("Sign out of chat™?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { Task { await auth.signOut() } }
            } message: {
                Text("You'll need to sign in again to chat.")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
