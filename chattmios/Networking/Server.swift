import Foundation

nonisolated enum Server {
    /// Base URL of the chattm backend.
    static let baseURL = URL(string: "https://chattm.app")!
    static let origin = "https://chattm.app"

    static func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        return comps.url!
    }
}

enum ServerError: LocalizedError {
    case unauthorized
    case badResponse(Int)
    case noSession
    case message(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Your session is no longer valid. Please sign in again."
        case .badResponse(let code): return "The server returned an error (\(code))."
        case .noSession: return "You are not signed in."
        case .message(let text): return text
        }
    }
}
