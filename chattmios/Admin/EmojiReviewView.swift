import SwiftUI

struct EmojiReviewView: View {
    @Environment(AuthManager.self) private var auth

    @State private var items: [PendingEmoji] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var denyTarget: PendingEmoji?
    @State private var denyReason = ""

    private var pendingItems: [PendingEmoji] { items.filter(\.isPending) }
    private var reviewedItems: [PendingEmoji] { items.filter { !$0.isPending } }

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage))
            } else if items.isEmpty {
                ContentUnavailableView("No submissions",
                    systemImage: "checkmark.circle",
                    description: Text("The emoji queue is empty."))
            } else {
                if !pendingItems.isEmpty {
                    Section("Pending — \(pendingItems.count)") {
                        ForEach(pendingItems) { emoji in
                            EmojiQueueRow(emoji: emoji) {
                                perform(emoji, accept: true)
                            } onDeny: {
                                denyTarget = emoji
                            }
                        }
                    }
                }

                if !reviewedItems.isEmpty {
                    Section("Reviewed — \(reviewedItems.count)") {
                        ForEach(reviewedItems) { emoji in
                            ReviewedEmojiRow(emoji: emoji)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .macOSReadableWidth(560)
        .navigationTitle("Emoji Queue")
        .inlineNavigationTitle()
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $denyTarget) { emoji in
            DenyReasonSheet(emoji: emoji, reason: $denyReason) {
                perform(emoji, accept: false, reason: denyReason)
                denyTarget = nil
                denyReason = ""
            }
            .presentationDetents([.medium])
        }
    }

    private func load() async {
        guard let session = auth.session else { return }
        loading = true
        defer { loading = false }
        do {
            items = try await RESTClient.shared.pendingEmojis(session: session)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func perform(_ emoji: PendingEmoji, accept: Bool, reason: String? = nil) {
        guard let session = auth.session else { return }
        Task {
            try? await RESTClient.shared.reviewEmoji(id: emoji.id, accept: accept,
                                                     reason: reason, session: session)
            await load()
            Haptics.success()
        }
    }
}

// MARK: - Pending row

private struct EmojiQueueRow: View {
    let emoji: PendingEmoji
    let onAccept: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: emoji.url)) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 52, height: 52)
                .background(.quaternary, in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(":\(emoji.shortcode):").font(.subheadline.weight(.semibold))
                    if let by = emoji.submittedBy {
                        Text(by).font(.caption).foregroundStyle(.secondary)
                    }
                    if let date = emoji.submittedAt {
                        Text(date, style: .relative)
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onDeny) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)

                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2).foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let notes = emoji.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reviewed row

private struct ReviewedEmojiRow: View {
    let emoji: PendingEmoji

    private var statusColor: Color {
        switch emoji.status {
        case "accepted": return .green
        case "denied": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: emoji.url)) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 40, height: 40)
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .opacity(0.6)

            VStack(alignment: .leading, spacing: 3) {
                Text(":\(emoji.shortcode):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let by = emoji.submittedBy {
                    Text(by).font(.caption).foregroundStyle(.tertiary)
                }
                if let reason = emoji.reviewReason, !reason.isEmpty {
                    Text("Reason: \(reason)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(emoji.status?.capitalized ?? "")
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Deny reason sheet

private struct DenyReasonSheet: View {
    let emoji: PendingEmoji
    @Binding var reason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: emoji.url)) { img in
                            img.resizable().scaledToFit()
                        } placeholder: { ProgressView() }
                        .frame(width: 56, height: 56)
                        .background(.quaternary, in: .rect(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(":\(emoji.shortcode):").font(.headline)
                            if let by = emoji.submittedBy {
                                Text(by).font(.caption).foregroundStyle(.secondary)
                            }
                            if let notes = emoji.notes, !notes.isEmpty {
                                Text(notes).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Reason (optional)") {
                    TextField("Why is this being denied?", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Deny Emoji")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Deny", role: .destructive) { onConfirm() }
                        .tint(.red)
                }
            }
        }
    }
}
