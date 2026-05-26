import Foundation
import Security
import Observation

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case serverError(Int, String)
    case keychainError(OSStatus)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid username or password."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .keychainError(let status): return "Keychain error: \(status)"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        }
    }
}

@Observable
final class AuthManager: Sendable {
    private let keychainService = "com.m1circuit.pitwall"
    private let keychainTokenAccount = "bearer_token"
    private let baseURL: URL

    private(set) var isAuthenticated: Bool = false
    private(set) var token: String?

    init(baseURL: URL = URL(string: "https://pitwall.m1circuit.com")!) {
        self.baseURL = baseURL
        token = loadTokenFromKeychain()
        isAuthenticated = token != nil
    }

    // MARK: - Public API

    func login(username: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("/api/pitwall/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.networkError(URLError(.badServerResponse))
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.serverError(http.statusCode, message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let authToken: AuthToken
        do {
            authToken = try decoder.decode(AuthToken.self, from: data)
        } catch {
            throw AuthError.decodingError(error)
        }

        try saveTokenToKeychain(authToken.token)
        token = authToken.token
        isAuthenticated = true
    }

    func logout() {
        deleteTokenFromKeychain()
        token = nil
        isAuthenticated = false
    }

    // MARK: - Keychain

    private func saveTokenToKeychain(_ tokenValue: String) throws {
        guard let data = tokenValue.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainTokenAccount,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw AuthError.keychainError(addStatus)
            }
        } else if status != errSecSuccess {
            throw AuthError.keychainError(status)
        }
    }

    private func loadTokenFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainTokenAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let tokenValue = String(data: data, encoding: .utf8)
        else { return nil }
        return tokenValue
    }

    private func deleteTokenFromKeychain() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainTokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
