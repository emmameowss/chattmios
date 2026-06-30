import SwiftUI
import WebKit

/// Drives the Hack Club OAuth flow in a WKWebView and captures the
/// `#session=...` fragment that the server appends on success.
struct HCAWebAuthView: View {
    let onSession: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Sign in").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
            WebAuthContainer(startURL: Server.url("login"), onSession: onSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 520)
        .dismissOnOutsideClick { dismiss() }
        #else
        NavigationStack {
            WebAuthContainer(startURL: Server.url("login"), onSession: onSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Sign in")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        #endif
    }
}

#if os(iOS)
private struct WebAuthContainer: UIViewRepresentable {
    let startURL: URL
    let onSession: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSession: onSession) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#else
private struct WebAuthContainer: NSViewRepresentable {
    let startURL: URL
    let onSession: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSession: onSession) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif

extension WebAuthContainer {
    final class Coordinator: NSObject, WKNavigationDelegate {
        let onSession: (String) -> Void
        private var fired = false
        init(onSession: @escaping (String) -> Void) { self.onSession = onSession }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, let session = Self.session(from: url) {
                if !fired { fired = true; onSession(session) }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url, let session = Self.session(from: url), !fired {
                fired = true
                onSession(session)
            }
        }

        static func session(from url: URL) -> String? {
            guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else { return nil }
            for pair in fragment.components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2, kv[0] == "session", !kv[1].isEmpty { return kv[1] }
            }
            return nil
        }
    }
}
