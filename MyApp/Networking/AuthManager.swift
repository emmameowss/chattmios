import Foundation
import Observation

/// Owns the session token and the signed-in identity.
@Observable
@MainActor
final class AuthManager {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var state: State = .loading
    private(set) var session: String?
    var currentUsername: String?
    private(set) var isGuest: Bool = false

    var errorMessage: String?

    private let sessionKey = "session"

    init() {
        self.session = Keychain.get(sessionKey)
        #if DEBUG
        // Testing hook: seed a session via the environment (SIMCTL_CHILD_CHATTM_DEBUG_SESSION=...).
        if let debug = ProcessInfo.processInfo.environment["CHATTM_DEBUG_SESSION"], !debug.isEmpty {
            self.session = debug
        }
        #endif
    }

    /// Validate any stored session on launch.
    func bootstrap() async {
        guard let session, !session.isEmpty else {
            state = .signedOut
            return
        }
        do {
            let me = try await RESTClient.shared.me(session: session)
            currentUsername = me.username
            isGuest = me.guest
            state = .signedIn
        } catch {
            // Stored session no longer valid.
            clearLocal()
            state = .signedOut
        }
    }

    func continueAsGuest(username: String?) async {
        errorMessage = nil
        do {
            let session = try await RESTClient.shared.guestLogin(username: username)
            await store(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called by the HCA web auth flow once a `#session=` token is captured.
    func completeWebAuth(session: String) async {
        await store(session: session)
    }

    private func store(session: String) async {
        Keychain.set(session, for: sessionKey)
        self.session = session
        do {
            let me = try await RESTClient.shared.me(session: session)
            currentUsername = me.username
            isGuest = me.guest
            state = .signedIn
        } catch {
            // Token accepted but /me failed; still treat as signed in.
            state = .signedIn
        }
    }

    func signOut() async {
        if let session { await RESTClient.shared.signOut(session: session) }
        clearLocal()
        state = .signedOut
    }

    private func clearLocal() {
        Keychain.delete(sessionKey)
        session = nil
        currentUsername = nil
        isGuest = false
    }
}
