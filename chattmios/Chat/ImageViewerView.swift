import SwiftUI

/// Full-screen zoomable image viewer.
struct ImageViewerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissOffset: CGSize = .zero

    private var backgroundOpacity: Double {
        max(0, 1 - Double(abs(dismissOffset.height)) / 280 * 0.8)
    }

    private var dismissShrink: CGFloat {
        max(0.85, 1 - abs(dismissOffset.height) / 500 * 0.15)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle).foregroundStyle(.white)
                default:
                    ProgressView().tint(.white)
                }
            }
            .scaleEffect(scale * dismissShrink)
            .offset(CGSize(
                width: offset.width + dismissOffset.width,
                height: offset.height + dismissOffset.height))
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = max(1, lastScale * value.magnification) }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1 { withAnimation { offset = .zero; lastOffset = .zero } }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1 {
                            offset = CGSize(width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height)
                        } else if value.translation.height > 0 {
                            dismissOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if scale > 1 {
                            lastOffset = offset
                        } else {
                            let shouldDismiss = value.translation.height > 120
                                || value.predictedEndTranslation.height > 350
                            if shouldDismiss {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    dismissOffset = CGSize(width: dismissOffset.width, height: 700)
                                }
                                Task {
                                    try? await Task.sleep(for: .milliseconds(210))
                                    dismiss()
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    dismissOffset = .zero
                                }
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation {
                    if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                    else { scale = 2.5; lastScale = 2.5 }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(12)
                    .glassCapsule()
            }
            .padding()
            .opacity(backgroundOpacity)
        }
        .overlay(alignment: .bottom) {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassCapsule()
            }
            .padding(.bottom, 30)
            .opacity(backgroundOpacity)
        }
    }
}
