import SwiftUI
import PhotosUI

struct EmojiSuggestView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var shortcode = ""
    @State private var notes = ""
    @State private var imageItem: PhotosPickerItem?
    #if canImport(UIKit)
    @State private var imagePreview: UIImage?
    #else
    @State private var imagePreview: NSImage?
    #endif
    @State private var imagePayload: (data: Data, ext: String, mime: String)?
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var autoApproved = false

    private var normalizedCode: String {
        shortcode.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .filter { $0 != ":" }
    }

    private var codeValid: Bool {
        !normalizedCode.isEmpty &&
        normalizedCode.range(of: #"^[a-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    private var canSubmit: Bool { codeValid && imagePayload != nil && !submitting }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $imageItem, matching: .images) {
                            if let img = imagePreview {
                                Image(platformImage: img)
                                    .resizable().scaledToFit()
                                    .frame(width: 88, height: 88)
                                    .clipShape(.rect(cornerRadius: 14))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.quaternary)
                                        .frame(width: 88, height: 88)
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.largeTitle)
                                            .foregroundStyle(Brand.accent)
                                        Text("Tap to choose")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Shortcode") {
                    HStack {
                        Text(":").foregroundStyle(.secondary).font(.dmMono(16))
                        TextField("name", text: $shortcode)
                            .noAutocapitalization()
                            .autocorrectionDisabled()
                            .font(.dmMono(16))
                            .onChange(of: shortcode) { _, v in
                                shortcode = v.filter { $0 != ":" }
                            }
                        Text(":").foregroundStyle(.secondary).font(.dmMono(16))
                    }
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Suggest Emoji")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if submitting {
                        ProgressView()
                    } else {
                        Button("Submit") { submit() }.disabled(!canSubmit)
                    }
                }
            }
            .onChange(of: imageItem) { _, item in
                guard let item else { return }
                Task { await loadImage(item) }
            }
            .alert("Submitted!", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text(autoApproved
                     ? "Your emoji was auto-approved and is now live."
                     : "Your emoji is pending review by the admin.")
            }
        }
    }

    private func loadImage(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "png"
        let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/png"
        #if canImport(UIKit)
        let preview = UIImage(data: data)
        #else
        let preview = NSImage(data: data)
        #endif
        imagePayload = (data, ext, mime)
        imagePreview = preview
    }

    private func submit() {
        guard let session = auth.session,
              let username = auth.currentUsername,
              let img = imagePayload else { return }
        let code = ":\(normalizedCode):"
        submitting = true
        errorMessage = nil
        Task {
            do {
                autoApproved = try await RESTClient.shared.suggestEmoji(
                    shortcode: code,
                    imageData: img.data,
                    mimeType: img.mime,
                    ext: img.ext,
                    notes: notes.isEmpty ? nil : notes,
                    username: username,
                    session: session
                )
                showSuccess = true
                Haptics.success()
            } catch {
                errorMessage = error.localizedDescription
                Haptics.warning()
            }
            submitting = false
        }
    }
}
