import SwiftUI

/// The "Profile" tab — the signed-in user's own profile, with an edit entry point.
struct MyProfileView: View {
    @Environment(SocketService.self) private var socket
    @Environment(AuthManager.self) private var auth
    @State private var showEdit = false
    @State private var status: PresenceStatus = .online

    private var username: String { auth.currentUsername ?? "guest" }
    private var profile: UserProfile? { socket.profiles[username] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let profile {
                        ProfileHeader(profile: profile)
                        ProfileDetails(profile: profile, showStatus: false)
                    } else {
                        VStack(spacing: 12) {
                            AvatarView(username: username, avatarURL: nil, size: 110)
                            Text(username).font(.title2.bold())
                            if auth.isGuest {
                                Text("You're browsing as a guest.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    }

                    GlassCard {
                        HStack {
                            Label("Status", systemImage: "circle.fill")
                                .foregroundStyle(StatusDot(status: status).color)
                            Spacer()
                            Picker("Status", selection: $status) {
                                Text("Online").tag(PresenceStatus.online)
                                Text("Idle").tag(PresenceStatus.idle)
                                Text("Do Not Disturb").tag(PresenceStatus.dnd)
                            }
                            .pickerStyle(.menu)
                            .tint(Brand.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    if auth.isGuest {
                        GlassCard {
                            Label("Sign in with Hack Club to customize your profile, set an avatar, and keep your name.",
                                  systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }
                }
                .macOSReadableWidth()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showEdit = true
                    } label: { Label("Edit", systemImage: "pencil") }
                        .disabled(auth.isGuest)
                }
            }
            .sheet(isPresented: $showEdit, onDismiss: { socket.getProfile(username) }) {
                if let profile { ProfileEditView(profile: profile) }
            }
            .task { socket.getProfile(username) }
            .refreshable { socket.getProfile(username) }
            .onChange(of: profile?.status) { _, newValue in
                if let newValue, newValue != .offline { status = newValue }
            }
            .onChange(of: status) { _, newValue in
                socket.setStatus(newValue)
            }
        }
        .fillAvailableSpace()
    }
}
