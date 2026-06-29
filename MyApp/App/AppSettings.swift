import SwiftUI
import Observation

/// User-facing preferences, mirroring the web client's localStorage flags.
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var notificationsMuted: Bool {
        didSet { defaults.set(notificationsMuted, forKey: Keys.notifyMuted) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let appearance = "pref.appearance"
        static let notifyMuted = "pref.notifymuted"
    }

    init() {
        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.notificationsMuted = defaults.bool(forKey: Keys.notifyMuted)
    }
}
