import SwiftUI
import ClerkKit
#if os(macOS)
import UniformTypeIdentifiers
#else
import PhotosUI
#endif

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
    @State private var showColorPicker = false
    #if os(macOS)
    @State private var showAvatarPicker = false
    #else
    @State private var avatarItem: PhotosPickerItem?
    #endif
    @State private var uploadingAvatar = false

    /// The authoritative avatar, kept fresh as `savedAvatar` re-fetches land.
    /// The picture itself lives in Clerk; broader account management is in Settings.
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
                        ZStack {
                            AvatarView(username: username.isEmpty ? profile.username : username,
                                       avatarURL: displayedAvatar, size: 96)
                            if uploadingAvatar { ProgressView().tint(.white) }
                        }
                        // The picture lives in Clerk; we push changes there and
                        // then ask the server to re-sync the in-app avatar.
                        HStack(spacing: 16) {
                            #if os(macOS)
                            Button { showAvatarPicker = true } label: {
                                Label("Change", systemImage: "photo")
                            }
                            .fileImporter(isPresented: $showAvatarPicker, allowedContentTypes: [.image]) { result in
                                if case .success(let url) = result { Task { await uploadAvatarFile(url) } }
                            }
                            #else
                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                Label("Change", systemImage: "photo")
                            }
                            #endif
                            if displayedAvatar != nil {
                                Button(role: .destructive) {
                                    Task { await removeAvatar() }
                                } label: { Label("Remove", systemImage: "trash") }
                            }
                        }
                        .font(.caption)
                        .disabled(auth.isGuest || uploadingAvatar)
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
        #if !os(macOS)
        .onChange(of: avatarItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatarItem(item); avatarItem = nil }
        }
        #endif
        .onChange(of: socket.avatarSyncTick) { _, _ in
            // Server confirmed a Clerk avatar sync → refresh our copy.
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

    // MARK: Profile picture (stored in Clerk)

    /// Upload new image data to Clerk, then have the server re-sync the avatar.
    private func setAvatar(data: Data) async {
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        do {
            _ = try await Clerk.shared.user?.setProfileImage(imageData: data)
            socket.refreshAvatar()
            Haptics.success()
        } catch {
            Haptics.warning()
        }
    }

    private func removeAvatar() async {
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        do {
            _ = try await Clerk.shared.user?.deleteProfileImage()
            socket.refreshAvatar()
            Haptics.success()
        } catch {
            Haptics.warning()
        }
    }

    #if os(macOS)
    private func uploadAvatarFile(_ fileURL: URL) async {
        _ = fileURL.startAccessingSecurityScopedResource()
        defer { fileURL.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        await setAvatar(data: data)
    }
    #else
    private func uploadAvatarItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await setAvatar(data: data)
    }
    #endif
}
