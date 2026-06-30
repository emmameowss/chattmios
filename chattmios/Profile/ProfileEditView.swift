import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    #if os(macOS)
    @State private var showAvatarPicker = false
    #else
    @State private var avatarItem: PhotosPickerItem?
    #endif
    @State private var avatarPreview: String?
    @State private var uploadingAvatar = false
    @State private var showColorPicker = false

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
                                       avatarURL: avatarPreview ?? profile.avatar, size: 96)
                            if uploadingAvatar {
                                ProgressView().tint(.white)
                            }
                        }
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
        .onChange(of: avatarItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(item); avatarItem = nil }
        }
        #endif
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

    #if os(macOS)
    private func uploadAvatarFile(_ fileURL: URL) async {
        guard let session = auth.session else { return }
        _ = fileURL.startAccessingSecurityScopedResource()
        defer { fileURL.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        uploadingAvatar = true
        defer { uploadingAvatar = false }
        let ext = fileURL.pathExtension.lowercased().isEmpty ? "jpg" : fileURL.pathExtension.lowercased()
        let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "image/jpeg"
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
    #else
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
    #endif
}
