import Foundation

/// Async wrappers around chattm's HTTP endpoints.
final class RESTClient: NSObject, URLSessionTaskDelegate {
    static let shared = RESTClient()

    /// Default session (follows redirects).
    private lazy var session = URLSession(configuration: .default)
    /// Session that does NOT auto-follow redirects, so we can read `Location`.
    private lazy var noRedirectSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    // MARK: URLSessionTaskDelegate — block redirects on the no-redirect session
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil) // stop; we'll inspect the response ourselves
    }

    // MARK: Session helpers

    /// Extract `#session=...` from a redirect Location header.
    private func sessionFromLocation(_ location: String?) -> String? {
        guard let location, let frag = URLComponents(string: location)?.fragment ?? location.components(separatedBy: "#").dropFirst().first else {
            return nil
        }
        // fragment looks like "session=abcdef"
        for pair in frag.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2, kv[0] == "session" { return kv[1] }
        }
        return nil
    }

    /// Create a guest session, optionally requesting a username.
    func guestLogin(username: String?) async throws -> String {
        var query: [URLQueryItem] = []
        if let username, !username.isEmpty { query.append(.init(name: "username", value: username)) }
        let url = Server.url("guest", query: query)
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await noRedirectSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ServerError.badResponse(0) }
        if (300...399).contains(http.statusCode) {
            let location = http.value(forHTTPHeaderField: "Location") ?? ""
            if location.contains("guests_disabled") {
                throw ServerError.message("Guest sign-in is currently disabled.")
            }
            if let session = sessionFromLocation(location) {
                return session
            }
        }
        // Some deployments may return JSON {session:...}
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let session = obj["session"] as? String {
            return session
        }
        throw ServerError.message("Could not start a guest session.")
    }

    /// Validate a session, returning the stored username and guest flag.
    func me(session: String) async throws -> (username: String?, guest: Bool) {
        let url = Server.url("me", query: [.init(name: "session", value: session)])
        let (data, response) = try await self.session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ServerError.badResponse(0) }
        if http.statusCode == 401 { throw ServerError.unauthorized }
        guard http.statusCode == 200 else { throw ServerError.badResponse(http.statusCode) }
        let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (obj["username"] as? String, (obj["guest"] as? Bool) ?? false)
    }

    func signOut(session: String) async {
        let url = Server.url("signout", query: [.init(name: "session", value: session)])
        _ = try? await self.session.data(from: url)
    }

    func maintenance() async throws -> MaintenanceInfo {
        let (data, _) = try await session.data(from: Server.url("maintenance"))
        return try JSONDecoder().decode(MaintenanceInfo.self, from: data)
    }

    func stats() async throws -> ServerStats {
        let (data, _) = try await session.data(from: Server.url("stats"))
        return try JSONDecoder().decode(ServerStats.self, from: data)
    }

    func version() async throws -> VersionInfo {
        let (data, _) = try await session.data(from: Server.url("version"))
        return try JSONDecoder().decode(VersionInfo.self, from: data)
    }

    // MARK: Upload

    /// Upload an image/file and return its hosted URL.
    /// - Parameter avatar: true to store under /avatars (used for profile pictures).
    func upload(data: Data, filename: String, mimeType: String,
                username: String, session: String, avatar: Bool) async throws -> String {
        let url = Server.url("upload", query: [
            .init(name: "session", value: session),
            .init(name: "avatar", value: avatar ? "1" : "0"),
        ])
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(Server.origin, forHTTPHeaderField: "Origin")

        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"username\"\r\n\r\n")
        append("\(username)\r\n")
        if avatar {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"avatar\"\r\n\r\n")
            append("1\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let (respData, response) = try await self.session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ServerError.badResponse(0) }
        let obj = (try? JSONSerialization.jsonObject(with: respData) as? [String: Any]) ?? [:]
        if let urlString = obj["url"] as? String { return urlString }
        if let error = obj["error"] as? String { throw ServerError.message(error) }
        throw ServerError.badResponse(http.statusCode)
    }

    // MARK: Emoji moderation (owner)

    func pendingEmojis(session: String) async throws -> [PendingEmoji] {
        let url = Server.url("pending-emojis", query: [.init(name: "session", value: session)])
        let (data, response) = try await self.session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServerError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let raw: [[String: Any]]
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            raw = arr
        } else if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = obj["emojis"] as? [[String: Any]] {
            raw = arr
        } else {
            raw = []
        }
        return raw.compactMap(PendingEmoji.init(dict:))
    }

    func suggestEmoji(shortcode: String, imageData: Data, mimeType: String, ext: String,
                      notes: String?, username: String, session: String) async throws -> Bool {
        let url = Server.url("suggest-emoji", query: [.init(name: "session", value: session)])
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Server.origin, forHTTPHeaderField: "Origin")
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }

        for (name, value) in [("username", username), ("shortcode", shortcode)] {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        if let notes {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"notes\"\r\n\r\n")
            append("\(notes)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"emoji.\(ext)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(imageData)
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let (respData, response) = try await self.session.data(for: req)
        let obj = (try? JSONSerialization.jsonObject(with: respData) as? [String: Any]) ?? [:]
        if let error = obj["error"] as? String { throw ServerError.message(error) }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServerError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return (obj["autoApproved"] as? Bool) ?? false
    }

    func reviewEmoji(id: String, accept: Bool, reason: String? = nil, session: String) async throws {
        let url = Server.url(accept ? "admin/emoji/accept" : "admin/emoji/deny")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Server.origin, forHTTPHeaderField: "Origin")
        var body: [String: Any] = ["id": id, "session": session]
        if let reason, !reason.isEmpty { body["reason"] = reason }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await self.session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServerError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}
