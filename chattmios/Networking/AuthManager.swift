import Foundation
import Observation
import ClerkKit

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

    /// Called once the user has signed in with Clerk. Exchanges the Clerk
    /// session JWT for one of our own app sessions via `/clerk-login`.
    func completeClerkLogin() async {
        errorMessage = nil
        do {
            guard let jwt = try await Clerk.shared.auth.getToken() else {
                errorMessage = "Could not read your sign-in. Please try again."
                return
            }
            let session = try await RESTClient.shared.clerkLogin(token: jwt)
            await store(session: session)
        } catch {
            errorMessage = error.localizedDescription
        }
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
        // End the Clerk session too, so a real-account user isn't silently
        // re-signed-in. Guests have no Clerk session; this is then a no-op.
        try? await Clerk.shared.auth.signOut()
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
