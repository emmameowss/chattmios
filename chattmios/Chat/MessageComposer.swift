import SwiftUI
import PhotosUI

struct MessageComposer: View {
    @Bindable var model: ChatViewModel
    @Environment(SocketService.self) private var socket

    @State private var photoItem: PhotosPickerItem?
    @State private var showEmojiPicker = false
    @State private var showEmojiSuggest = false
    @FocusState private var focused: Bool

    private var suggestions: [Autocomplete.Suggestion] {
        Autocomplete.suggestions(
            for: model.composerText,
            users: socket.users.map(\.username),
            emoji: socket.emojiMap,
            isOwner: socket.isOwner)
    }

    var body: some View {
        VStack(spacing: 8) {
            if let error = model.uploadError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if let pending = model.pendingImage {
                pendingImagePreview(pending)
            }
            if !suggestions.isEmpty {
                suggestionBar
            }
            if socket.chatMuted && !socket.isOwner {
                Text("Chat is currently muted by an admin.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .frame(width: 32, height: 36)
                        .foregroundStyle(Color.secondary)
                }
                .disabled(model.isUploading)

                Button { toggleEmojiPicker() } label: {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                        .frame(width: 32, height: 36)
                        .foregroundStyle(showEmojiPicker ? Brand.accent : Color.secondary)
                }

                TextField("Message chat™", text: $model.composerText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($focused)
                    .onChange(of: model.composerText) { _, _ in model.textChanged() }
                    .onChange(of: focused) { _, isFocused in
                        if isFocused { withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = false } }
                    }
                    .onSubmit { model.send() }

                if model.isUploading {
                    ProgressView().frame(width: 36, height: 36)
                } else {
                    Button { model.send(); focused = true } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(canSend ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.secondary))
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .glassPanel(cornerRadius: 24)

            if showEmojiPicker {
                EmojiPickerPanel(emoji: socket.emojiMap) { code in
                    insertEmoji(code)
                } onClose: {
                    withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = false }
                } onSuggest: {
                    withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker = false }
                    showEmojiSuggest = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard focused,
                          value.translation.height > 30,
                          abs(value.translation.height) > abs(value.translation.width) else { return }
                    focused = false
                    Haptics.tap()
                }
        )
        .onChange(of: model.focusRequest) { _, requested in
            if requested { focused = true; model.focusRequest = false }
        }
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task { await attachPhoto(newValue); photoItem = nil }
        }
        .sheet(isPresented: $showEmojiSuggest) { EmojiSuggestView() }
    }

    private func toggleEmojiPicker() {
        if !showEmojiPicker { focused = false }   // swap the keyboard for the panel
        withAnimation(.easeOut(duration: 0.2)) { showEmojiPicker.toggle() }
    }

    /// Append `:code:` to the message, keeping a sensible space before it.
    private func insertEmoji(_ code: String) {
        var text = model.composerText
        if !text.isEmpty && !text.hasSuffix(" ") { text += " " }
        text += ":\(code): "
        model.composerText = text
    }

    private var canSend: Bool {
        !model.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.pendingImage != nil
    }

    @ViewBuilder
    private func pendingImagePreview(_ pending: PendingImage) -> some View {
        HStack(spacing: 0) {
            if let uiImage = pending.preview {
                #if canImport(UIKit)
                Image(uiImage: uiImage)
                #else
                Image(nsImage: uiImage)
                #endif
                    .resizable().scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        Button { model.pendingImage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color(.systemGray))
                        }
                        .offset(x: 6, y: -6)
                    }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        model.composerText = Autocomplete.apply(suggestion, to: model.composerText)
                    } label: {
                        suggestionLabel(suggestion)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .glassCapsule(interactive: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private func suggestionLabel(_ suggestion: Autocomplete.Suggestion) -> some View {
        switch suggestion {
        case .command(let cmd):
            VStack(alignment: .leading, spacing: 0) {
                Text(cmd.display).font(.caption.weight(.semibold))
                Text(cmd.summary).font(.caption2).foregroundStyle(.secondary)
            }
        case .mention(let name):
            Label(name, systemImage: "at").font(.caption)
        case .emoji(let code, let url):
            HStack(spacing: 5) {
                AsyncImage(url: URL(string: url)) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                    .frame(width: 18, height: 18)
                Text(":\(code):").font(.caption)
            }
        }
    }

    private func attachPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
        let mime = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
        model.attachImage(data: data, filename: "upload.\(ext)", mime: mime)
    }
}
