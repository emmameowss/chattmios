import SwiftUI

@main
struct ChattmApp: App {
    @State private var auth = AuthManager()
    @State private var settings = AppSettings()
    @State private var socket = SocketService()

    init() {
        AppFonts.registerIfNeeded()
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(settings)
                .environment(socket)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Brand.accent)
        }
    }
}
