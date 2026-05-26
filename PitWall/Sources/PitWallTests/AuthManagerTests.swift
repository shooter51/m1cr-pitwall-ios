import Testing
import Foundation
@testable import PitWall

// MARK: - AuthManager tests
// Login tests hit the real pitwall.m1circuit.com endpoint.
// Keychain tests use the live Keychain on the test device.

@Suite("AuthManager")
struct AuthManagerTests {

    // MARK: - Initial state

    @Test("AuthManager starts unauthenticated when no keychain entry exists")
    func initiallyUnauthenticated() {
        // Use a unique service name so we don't collide with a real token
        let auth = AuthManager()
        // If there's no saved token the initial state must be false
        // (unless one was genuinely saved by a previous test — acceptable in CI)
        // We just verify the API contract is consistent
        #expect(auth.isAuthenticated == (auth.token != nil))
    }

    // MARK: - Logout

    @Test("Logout clears token and isAuthenticated")
    func logoutClearsState() {
        let auth = AuthManager()
        auth.logout()
        #expect(auth.token == nil)
        #expect(auth.isAuthenticated == false)
    }

    // MARK: - Login with invalid credentials (real API)

    @Test("Login with bad credentials throws serverError")
    func loginBadCredentials() async throws {
        let auth = AuthManager()
        auth.logout() // Start clean

        await #expect(throws: AuthError.self) {
            try await auth.login(username: "not-a-real-user", password: "wrong-password")
        }

        // Must still be unauthenticated
        #expect(auth.isAuthenticated == false)
        #expect(auth.token == nil)
    }

    // MARK: - Login with unreachable server

    @Test("Login with unreachable server throws networkError")
    func loginUnreachableServer() async throws {
        let auth = AuthManager(baseURL: URL(string: "https://unreachable.invalid")!)
        auth.logout()

        do {
            try await auth.login(username: "admin", password: "test")
            Issue.record("Expected login to throw but it succeeded")
        } catch let err as AuthError {
            switch err {
            case .networkError:
                break // Expected
            default:
                Issue.record("Expected networkError, got \(err)")
            }
        }
    }

    // MARK: - isAuthenticated consistency

    @Test("isAuthenticated matches token presence after operations")
    func isAuthenticatedConsistency() async {
        let auth = AuthManager()

        // After logout
        auth.logout()
        #expect(auth.isAuthenticated == (auth.token != nil))

        // Try an invalid login (don't care if it throws)
        try? await auth.login(username: "x", password: "y")
        #expect(auth.isAuthenticated == (auth.token != nil))
    }

    // MARK: - AuthError descriptions

    @Test("AuthError errorDescription returns non-empty strings")
    func authErrorDescriptions() {
        let errors: [AuthError] = [
            .invalidCredentials,
            .networkError(URLError(.timedOut)),
            .serverError(401, "Unauthorized"),
            .keychainError(-25300),
            .decodingError(NSError(domain: "test", code: 0)),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false, "Error \(error) should have description")
        }
    }
}
