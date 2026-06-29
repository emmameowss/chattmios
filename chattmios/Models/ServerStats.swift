import Foundation

/// Response from `GET /stats`.
struct ServerStats: Decodable {
    var users: Int?
    var messages: Int?
    var emoji: Int?
    var totalSize: Double?
    var uploads: Int?

    var formattedSize: String? {
        guard let totalSize else { return nil }
        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        return fmt.string(fromByteCount: Int64(totalSize))
    }
}

/// Response from `GET /maintenance`.
struct MaintenanceInfo: Decodable {
    var maintenance: Bool
    var reason: String?
    var guestsDisabled: Bool

    private enum CodingKeys: String, CodingKey {
        case maintenance, reason, guestsDisabled
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maintenance = (try? c.decode(Bool.self, forKey: .maintenance)) ?? false
        reason = try? c.decode(String.self, forKey: .reason)
        guestsDisabled = (try? c.decode(Bool.self, forKey: .guestsDisabled)) ?? false
    }
}

/// Response from `GET /version`.
struct VersionInfo: Decodable {
    var upToDate: Bool?
    var behind: Int?
    var latestCommit: String?
    var currentCommit: String?

    /// The running server commit (used for display).
    var commit: String? { currentCommit }
}
