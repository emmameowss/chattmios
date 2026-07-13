import SwiftUI
import ClerkKit

@main
struct ChattmApp: App {
    @State private var auth = AuthManager()
    @State private var settings = AppSettings()
    @State private var socket = SocketService()

    init() {
        AppFonts.registerIfNeeded()
        NotificationManager.shared.configure()
        // Clerk is the identity provider for real accounts (mirrors the web
        // client's clerk-js). The publishable key is public and safe to embed.
        Clerk.configure(publishableKey: "pk_live_Y2xlcmsuY2hhdHRtLmFwcCQ")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(settings)
                .environment(socket)
                .environment(Clerk.shared)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Brand.accent)
                #if os(macOS)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 620)
        #endif
    }
}
