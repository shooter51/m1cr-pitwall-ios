import Foundation
import Observation

/// Holds the currently attached Mobile Command (URL + node identity), the
/// shared client key, and the lobby URL — all driven by the currently selected
/// `Backend` in `BackendStore`. Switching backends is allowed at runtime.
///
/// See `docs/PRD-mobile-command-v2.md` §"Hosting" and `docs/adr/0002-mc-runtime.md`.
@MainActor
@Observable
final class MCClient {
    /// Shared client key for the current Backend.
    private(set) var clientKey: String

    /// Lobby URL for the current Backend.
    private(set) var lobbyURL: URL

    /// Currently attached MC, or nil if the operator is still on the lobby board.
    private(set) var attached: LobbyNode?

    /// Convenience for handlers — the base URL of the attached MC.
    var attachedMCURL: URL? {
        guard let urlStr = attached?.mc.url else { return nil }
        return URL(string: urlStr)
    }

    /// The device identifier the iOS app sends when attaching.
    let deviceId: String

    init(clientKey: String, lobbyURL: URL, deviceId: String) {
        self.clientKey = clientKey
        self.lobbyURL = lobbyURL
        self.deviceId = deviceId
        self.attached = nil
    }

    /// Switch to a different Backend. Resets any current MC attachment because
    /// nodes from one Backend's forest are meaningless on another.
    func switchBackend(_ backend: Backend) {
        self.clientKey = backend.clientKey
        self.lobbyURL  = backend.lobbyURL
        self.attached  = nil
    }

    func attach(to node: LobbyNode) { self.attached = node }
    func detach() { self.attached = nil }

    /// Convenience to add the auth header to any URLRequest going to MC or Lobby.
    func authorize(_ request: inout URLRequest) {
        request.setValue(clientKey, forHTTPHeaderField: "X-PitWall-Key")
    }

    /// Whether the MC the operator just attached to is an Org node — used by
    /// ContentView to decide whether to expose the Race Wall tab.
    var attachedIsOrg: Bool { attached?.kind == .org }
}
