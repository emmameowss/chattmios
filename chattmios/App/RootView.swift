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
                        if let notice = socket.maintenanceNotice {
                            MaintenanceView(message: notice) {
                                socket.reconnect()
                            }
                            .transition(.opacity)
                        }
                    }
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
        .onChange(of: socket.disconnectNotice) { _, notice in
            // A forced disconnect (ban/kick) returns the user to sign-in.
            if notice != nil {
                Task { await auth.signOut() }
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
