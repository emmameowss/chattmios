import SwiftUI
import ClerkKit
import ClerkKitUI

struct ProfileEditView: View {
    let profile: UserProfile
    @Environment(SocketService.self) private var socket
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var pronouns: String = ""
    @State private var bio: String = ""
    @State private var status: PresenceStatus = .online
    @State private var localColor: String?
    @State private var showAccount = false
    @State private var showColorPicker = false

    /// The authoritative avatar, kept fresh as `savedAvatar` re-fetches land.
    private var displayedAvatar: String? {
        socket.profiles[profile.username]?.avatar ?? profile.avatar
    }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Edit Profile").font(.headline)
                Spacer()
                Button("Save") { save() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
            formContent
        }
        .frame(minWidth: 460, minHeight: 480)
        .dismissOnOutsideClick { dismiss() }
        #else
        NavigationStack {
            formContent
                .navigationTitle("Edit Profile")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
                }
        }
        #endif
    }

    private var formContent: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        AvatarView(username: username.isEmpty ? profile.username : username,
                                   avatarURL: displayedAvatar, size: 96)
                        // Profile pictures live in Clerk now, so avatar changes
                        // (and the rest of account management) happen in Clerk's
                        // account UI. We re-sync from Clerk when it dismisses.
                        Button {
                            showAccount = true
                        } label: {
                            Label("Manage Account", systemImage: "person.crop.circle")
                        }
                        .font(.caption)
                        .disabled(auth.isGuest)
                    }
                    Spacer()
                }
            }

            Section("Identity") {
                LabeledContent("Username") {
                    TextField("", text: $username)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .noAutocapitalization()
                }
                LabeledContent("Pronouns") {
                    TextField("optional", text: $pronouns)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Status", selection: $status) {
                    Text("Online").tag(PresenceStatus.online)
                    Text("Idle").tag(PresenceStatus.idle)
                    Text("Do Not Disturb").tag(PresenceStatus.dnd)
                }
                Button {
                    showColorPicker = true
                } label: {
                    HStack {
                        Text("Name Color").foregroundStyle(.primary)
                        Spacer()
                        ColoredName(name: username.isEmpty ? profile.username : username,
                                    color: NameColor(raw: localColor ?? profile.color), fallback: .secondary)
                    }
                }
                #if os(macOS)
                .popover(isPresented: $showColorPicker, arrowEdge: .trailing) {
                    NameColorPicker(current: localColor ?? profile.color) { value in
                        localColor = value
                        socket.sendCommand("/color \(value)", username: auth.currentUsername ?? username)
                        socket.getProfile(auth.currentUsername ?? username)
                        showColorPicker = false
                        Haptics.success()
                    }
                    .padding()
                    .frame(width: 340)
                }
                #endif
            }

            Section("Bio") {
                TextField("Tell people about yourself", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .labelsHidden()
            }
        }
        .formStyle(.grouped)
        #if !os(macOS)
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
        }
        #endif
        .sheet(isPresented: $showAccount, onDismiss: {
            // Pull the (possibly changed) picture back from Clerk.
            socket.refreshAvatar()
        }) {
            UserProfileView()
        }
        .onChange(of: socket.avatarSyncTick) { _, _ in
            // Server confirmed the Clerk avatar sync → refresh our copy.
            socket.getProfile(profile.username)
        }
        .onAppear {
            username = profile.username
            pronouns = profile.pronouns
            bio = profile.bio
            status = profile.status == .offline ? .online : profile.status
            localColor = profile.color
        }
    }

    #if !os(macOS)
    private var colorPickerSheet: some View {
        NavigationStack {
            ScrollView {
                NameColorPicker(current: localColor ?? profile.color) { value in
                    localColor = value
                    socket.sendCommand("/color \(value)", username: auth.currentUsername ?? username)
                    socket.getProfile(auth.currentUsername ?? username)
                    showColorPicker = false
                    Haptics.success()
                }
                .padding()
            }
            .navigationTitle("Name Color")
            .inlineNavigationTitle()
        }
        .presentationDetents([.medium, .large])
    }
    #endif

    private func save() {
        let effectiveName = username.trimmingCharacters(in: .whitespaces)
        if !effectiveName.isEmpty, effectiveName != profile.username {
            socket.setUsername(effectiveName)
            auth.currentUsername = effectiveName
        }
        if pronouns != profile.pronouns { socket.setPronouns(pronouns) }
        if bio != profile.bio { socket.setBio(bio) }
        if status != profile.status { socket.setStatus(status) }
        socket.getProfile(auth.currentUsername ?? profile.username)
        Haptics.success()
        dismiss()
    }
}
