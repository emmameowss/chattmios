import UserNotifications

/// Manages local notifications for @mentions. (The chattm server has no APNs
/// backend, so these are local notifications fired while the app is connected —
/// they appear as banners in the foreground and in Notification Center otherwise.)
nonisolated final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Set the delegate and request authorization. Safe to call multiple times.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Post a notification that `sender` mentioned the user.
    func notifyMention(from sender: String, text: String?) {
        let content = UNMutableNotificationContent()
        content.title = "\(sender) mentioned you"
        let body = (text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        content.body = body ?? "You were mentioned in chat™"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Show the banner even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
