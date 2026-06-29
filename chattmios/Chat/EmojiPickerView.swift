import SwiftUI

/// Inline emoji panel that docks above the tab bar (keyboard-style), so the
/// composer rises above it and the tab bar stays visible. Tapping inserts
/// `:shortcode:` and keeps the panel open for picking several.
struct EmojiPickerPanel: View {
    let emoji: [String: String]
    var onPick: (String) -> Void
    var onClose: () -> Void
    var onSuggest: () -> Void

    @State private var query = ""

    private var items: [EmojiItem] {
        emoji
            .map { EmojiItem(shortcode: $0.key, url: $0.value) }
            .filter { query.isEmpty || $0.shortcode.localizedCaseInsensitiveContains(query) }
            .sorted { $0.shortcode < $1.shortcode }
    }

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 8)]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search emoji", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.thinMaterial, in: .capsule)

                Button { onSuggest() } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Button { onClose() } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if emoji.isEmpty {
                Spacer()
                Text("This server has no custom emoji yet.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            } else if items.isEmpty {
                Spacer()
                Text("No emoji match “\(query)”.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(items) { item in
                            Button {
                                onPick(item.shortcode)
                                Haptics.tap()
                            } label: {
                                AsyncImage(url: URL(string: item.url)) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 34, height: 34)
                                .frame(width: 46, height: 46)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(12)
        .frame(height: 280)
        .background(.regularMaterial, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 8)
    }
}
