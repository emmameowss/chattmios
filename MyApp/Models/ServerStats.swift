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

/// Response from `GET /version`.
struct VersionInfo: Decodable {
    var upToDate: Bool?
    var behind: Int?
    var latestCommit: String?
    var currentCommit: String?

    /// The running server commit (used for display).
    var commit: String? { currentCommit }
}
