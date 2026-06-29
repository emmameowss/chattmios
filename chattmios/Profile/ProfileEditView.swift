import SwiftUI
import PhotosUI

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
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarPreview: String?
    @State private var uploadingAvatar = false
    @State private var showColorPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ZStack {
                                AvatarView(username: username.isEmpty ? profile.username : username,
                                           avatarURL: avatarPreview ?? profile.avatar, size: 96)
                                if uploadingAvatar {
                                    ProgressView().tint(.white)
                                }
                            }
                            HStack(spacing: 16) {
                                PhotosPicker(selection: $avatarItem, matching: .images) {
                                    Label("Change", systemImage: "photo")
                                }
                                if profile.avatar != nil || avatarPreview != nil {
                                    Button(role: .destructive) {
                                        socket.deleteAvatar()
                                        avatarPreview = nil
                                    } label: { Label("Remove", systemImage: "trash") }
                                }
                            }
                            .font(.caption)
                        }
                        Spacer()
                    }
                }

                Section("Identity") {
                    LabeledContent("Username") {
                        TextField("Username", text: $username)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Pronouns") {
                        TextField("they/them", text: $pronouns)
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
                }

                Section("Bio") {
                    TextField("Tell people about yourself", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .sheet(isPresented: $showColorPicker) {
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
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task { await uploadAvatar(item); avatarItem = nil }
            }
            .onAppear {
                username = profile.username
                pronouns = profile.pronouns
                bio = profile.bio
                status = profile.status == .offline ? .online : profile.status
                localColor = profile.color
            }
        }
    }

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

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard let session = auth.session,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
        do {
            let url = try await RESTClient.shared.upload(
                data: data, filename: "avatar.\(ext)", mimeType: mime,
                username: auth.currentUsername ?? username, session: session, avatar: true)
            socket.setAvatar(url)
            avatarPreview = url
            Haptics.success()
        } catch {
            Haptics.warning()
        }
    }
}
