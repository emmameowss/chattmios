import SwiftUI

struct MainTabView: View {
    @Environment(SocketService.self) private var socket

    var body: some View {
        TabView {
            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill") {
                ChatView()
            }
            Tab("Profile", systemImage: "person.crop.circle.fill") {
                MyProfileView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }

            if socket.isOwner {
                Tab("Admin", systemImage: "shield.lefthalf.filled") {
                    NavigationStack { AdminView() }
                }
            }
        }
    }
}
