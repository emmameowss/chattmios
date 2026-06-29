import SwiftUI

/// Owner review queue for user-submitted custom emoji.
struct EmojiReviewView: View {
    @Environment(AuthManager.self) private var auth

    @State private var pending: [PendingEmoji] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let error {
                ContentUnavailableView("Couldn't load", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if pending.isEmpty {
                ContentUnavailableView("No pending emoji", systemImage: "checkmark.circle", description: Text("The review queue is empty."))
            } else {
                ForEach(pending) { emoji in
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: emoji.url)) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(":\(emoji.shortcode):").font(.subheadline.weight(.semibold))
                            if let by = emoji.submittedBy {
                                Text(by).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button { review(emoji, accept: true) } label: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }.buttonStyle(.plain)
                        Button { review(emoji, accept: false) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                    .font(.title3)
                }
            }
        }
        .navigationTitle("Emoji Queue")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        guard let session = auth.session else { return }
        loading = true
        defer { loading = false }
        do {
            pending = try await RESTClient.shared.pendingEmojis(session: session)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func review(_ emoji: PendingEmoji, accept: Bool) {
        guard let session = auth.session else { return }
        Task {
            try? await RESTClient.shared.reviewEmoji(id: emoji.id, accept: accept, session: session)
            await load()
            Haptics.success()
        }
    }
}
