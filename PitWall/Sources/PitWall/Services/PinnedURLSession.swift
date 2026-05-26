import Foundation
import CryptoKit

/// Provides a shared URLSession that performs public-key pinning for
/// `*.m1circuit.com` domains.
///
/// In debug builds a pin mismatch logs a warning but does NOT fail the
/// connection, to avoid blocking development against local / staging servers.
/// In release builds a pin mismatch terminates the connection immediately.
///
/// Usage: replace `URLSession.shared` with `PinnedURLSession.shared` in
/// PitWallAPI, LobbyClient, and SSEClient.
final class PinnedURLSession: NSObject, URLSessionDelegate {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        let delegate = PinnedURLSession()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()

    private override init() {}

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Only pin m1circuit.com domains.
        guard host.hasSuffix("m1circuit.com") || host == "m1circuit.com" else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Extract the leaf certificate's public key hash.
        guard let serverCertificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = serverCertificates.first,
              let pubKey = SecCertificateCopyKey(leaf),
              let pubKeyData = SecKeyCopyExternalRepresentation(pubKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let pubKeyHash = sha256Base64(pubKeyData)
        let matches = Self.pinnedHashes.contains(pubKeyHash)

        if matches {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            #if DEBUG
            // In debug builds: warn and allow — local / staging servers won't match pins.
            print("[PinnedURLSession] WARNING: Certificate pin mismatch for \(host). " +
                  "Public key SHA-256: \(pubKeyHash). Allowing in DEBUG build.")
            completionHandler(.performDefaultHandling, nil)
            #else
            completionHandler(.cancelAuthenticationChallenge, nil)
            #endif
        }
    }

    // MARK: - Private

    /// SHA-256 of the SubjectPublicKeyInfo DER blob, base64-encoded.
    private func sha256Base64(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }

    /// Known-good public key hashes for *.m1circuit.com.
    /// Update these when certificates are rotated.
    /// Generate with: openssl s_client -connect pitwall.m1circuit.com:443 </dev/null 2>/dev/null |
    ///   openssl x509 -pubkey -noout |
    ///   openssl pkey -pubin -outform DER |
    ///   openssl dgst -sha256 -binary | base64
    private static let pinnedHashes: Set<String> = [
        // Leaf certificate (pitwall.m1circuit.com)
        "/qQY5mwOP4uGjHOVESg5jQOT/wIPp2Rpl2qAWV6GVj0=",
        // Intermediate certificate (backup pin)
        "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",
    ]
}
