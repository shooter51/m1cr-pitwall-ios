import Testing
import Foundation
@testable import PitWall

@Suite("MCClient")
struct MCClientTests {

    @MainActor
    private func makeClient() -> MCClient {
        MCClient(
            clientKey: "test-key",
            lobbyURL: URL(string: "https://pitwall.test.com")!,
            deviceId: "device-001"
        )
    }

    @MainActor
    @Test("switchBackend resets attached node")
    func switchBackendResetsAttached() {
        let mc = makeClient()
        let node = LobbyNode(
            id: "node-1", parentId: nil, name: "Test", slug: "test", kind: .location,
            metadata: [:],
            mc: .init(url: "http://localhost:8080", isRunning: true, startedAt: nil),
            operator: nil,
            live: .init(activeSessions: 0, activeRaces: 0, activePostings: 0)
        )
        mc.attach(to: node)
        #expect(mc.attached != nil)

        let newBackend = Backend(
            name: "New",
            lobbyURL: URL(string: "https://new.example.com")!,
            clientKey: "new-key"
        )
        mc.switchBackend(newBackend)

        #expect(mc.attached == nil)
        #expect(mc.clientKey == "new-key")
        #expect(mc.lobbyURL == URL(string: "https://new.example.com")!)
    }

    @MainActor
    @Test("attach and detach state")
    func attachDetach() {
        let mc = makeClient()
        let node = LobbyNode(
            id: "node-1", parentId: nil, name: "Bay A", slug: "bay-a", kind: .location,
            metadata: [:],
            mc: .init(url: "http://mc.local", isRunning: true, startedAt: nil),
            operator: nil,
            live: .init(activeSessions: 1, activeRaces: 0, activePostings: 0)
        )

        #expect(mc.attached == nil)
        #expect(mc.attachedMCURL == nil)

        mc.attach(to: node)
        #expect(mc.attached?.id == "node-1")
        #expect(mc.attachedMCURL == URL(string: "http://mc.local"))

        mc.detach()
        #expect(mc.attached == nil)
        #expect(mc.attachedMCURL == nil)
    }

    @MainActor
    @Test("authorize adds X-PitWall-Key header")
    func authorizeHeader() {
        let mc = makeClient()
        var request = URLRequest(url: URL(string: "https://example.com/api")!)

        mc.authorize(&request)

        #expect(request.value(forHTTPHeaderField: "X-PitWall-Key") == "test-key")
    }

    @MainActor
    @Test("attachedIsOrg returns true for org kind")
    func attachedIsOrg() {
        let mc = makeClient()
        let orgNode = LobbyNode(
            id: "org-1", parentId: nil, name: "HQ", slug: "hq", kind: .org,
            metadata: [:],
            mc: .init(url: nil, isRunning: false, startedAt: nil),
            operator: nil,
            live: .init(activeSessions: 0, activeRaces: 0, activePostings: 0)
        )
        mc.attach(to: orgNode)
        #expect(mc.attachedIsOrg == true)

        mc.detach()
        #expect(mc.attachedIsOrg == false)
    }

    @MainActor
    @Test("deviceId is preserved from init")
    func deviceIdPreserved() {
        let mc = makeClient()
        #expect(mc.deviceId == "device-001")
    }
}
