import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(SocketService.self) private var socket

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                SplashView()
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .transition(.opacity)
                    .overlay {
                        if let notice = socket.banNotice {
                            BannedView(
                                message: notice,
                                onReconnect: { socket.reconnect() },
                                onSignOut: { Task { await auth.signOut() } }
                            )
                            .transition(.opacity)
                        } else if let notice = socket.kickNotice {
                            KickedView(message: notice) {
                                socket.reconnect()
                            }
                            .transition(.opacity)
                        } else if let notice = socket.maintenanceNotice {
                            MaintenanceView(message: notice) {
                                socket.reconnect()
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut, value: socket.banNotice)
                    .animation(.easeInOut, value: socket.kickNotice)
                    .animation(.easeInOut, value: socket.maintenanceNotice)
            }
        }
        .animation(.easeInOut, value: auth.state)
        .task {
            await auth.bootstrap()
        }
        .onChange(of: auth.state) { _, newValue in
            if newValue == .signedIn, let session = auth.session {
                socket.connect(session: session)
            } else if newValue == .signedOut {
                socket.disconnect()
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Brand.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("chat™")
                    .font(.dmMono(44))
                    .foregroundStyle(Brand.gradient)
                ProgressView()
            }
        }
    }
}
