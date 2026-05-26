import Foundation

/// A PitWall backend the app can connect to. Each Backend captures the
/// well-known Lobby URL plus the shared client key that gates every request.
///
/// Operators may have several saved Backends — e.g. one for their own family
/// network plus the M1 Circuit default. The current Backend is what `MCClient`
/// uses for all HTTP/SSE traffic.
struct Backend: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var lobbyURL: URL
    var clientKey: String
    var lastConnectedAt: Date?

    init(id: UUID = UUID(), name: String, lobbyURL: URL, clientKey: String, lastConnectedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.lobbyURL = lobbyURL
        self.clientKey = clientKey
        self.lastConnectedAt = lastConnectedAt
    }

    /// Sensible display string — host of the URL when no name was given.
    var displayName: String {
        if !name.isEmpty { return name }
        return lobbyURL.host ?? lobbyURL.absoluteString
    }
}
