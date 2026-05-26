import Testing
import Foundation
@testable import PitWall

@Suite("Backend Model")
struct BackendModelTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = Backend(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
            name: "M1 Circuit",
            lobbyURL: URL(string: "https://pitwall.m1circuit.com")!,
            clientKey: "secret-key-abc",
            lastConnectedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Backend.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.lobbyURL == original.lobbyURL)
        #expect(decoded.clientKey == original.clientKey)
        #expect(decoded.lastConnectedAt != nil)
    }

    @Test("Codable round-trip with nil lastConnectedAt")
    func codableNilDate() throws {
        let original = Backend(
            name: "Local Dev",
            lobbyURL: URL(string: "http://localhost:3000")!,
            clientKey: "dev-key"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Backend.self, from: data)

        #expect(decoded.name == "Local Dev")
        #expect(decoded.lastConnectedAt == nil)
    }

    @Test("displayName returns name when non-empty")
    func displayNameWithName() {
        let backend = Backend(
            name: "My Server",
            lobbyURL: URL(string: "https://pitwall.example.com")!,
            clientKey: "key"
        )
        #expect(backend.displayName == "My Server")
    }

    @Test("displayName falls back to host when name is empty")
    func displayNameFallback() {
        let backend = Backend(
            name: "",
            lobbyURL: URL(string: "https://pitwall.example.com")!,
            clientKey: "key"
        )
        #expect(backend.displayName == "pitwall.example.com")
    }

    @Test("displayName falls back to full URL when no host")
    func displayNameNoHost() {
        // Edge case: a URL with no host component
        let backend = Backend(
            name: "",
            lobbyURL: URL(string: "file:///local/path")!,
            clientKey: "key"
        )
        // Should fall back to absoluteString since host is nil
        #expect(backend.displayName == "file:///local/path")
    }

    @Test("Hashable and Equatable work correctly")
    func hashableEquatable() {
        let id = UUID()
        let b1 = Backend(id: id, name: "A", lobbyURL: URL(string: "https://a.com")!, clientKey: "k")
        let b2 = Backend(id: id, name: "A", lobbyURL: URL(string: "https://a.com")!, clientKey: "k")
        let b3 = Backend(name: "B", lobbyURL: URL(string: "https://b.com")!, clientKey: "k2")

        #expect(b1 == b2)
        #expect(b1 != b3)
        #expect(b1.hashValue == b2.hashValue)
    }
}
