#if os(macOS)
import AppKit
import SwiftUI

extension View {
    func dismissOnOutsideClick(perform action: @escaping () -> Void) -> some View {
        background(OutsideClickDetector(action: action))
    }
}

private struct OutsideClickDetector: NSViewRepresentable {
    var action: () -> Void
    func makeNSView(context: Context) -> TrackingView { TrackingView(action: action) }
    func updateNSView(_ view: TrackingView, context: Context) { view.action = action }
}

final class TrackingView: NSView {
    var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let myWindow = window else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowResignedKey),
            name: NSWindow.didResignKeyNotification,
            object: myWindow
        )
    }

    @objc private func windowResignedKey() {
        DispatchQueue.main.async { [weak self] in self?.action() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
