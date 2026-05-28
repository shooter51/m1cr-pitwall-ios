import Testing
import Foundation
@testable import PitWall

// MARK: - PitWallAPI integration tests
// These tests hit the real pitwall.m1circuit.com API.
// Public endpoints (laps, competitions) require no auth.
// Admin endpoints (rigs, server-control) require an attached MC + valid key.

@Suite("PitWallAPI")
struct PitWallAPITests {
    let baseURL = URL(string: "https://pitwall.m1circuit.com")!

    @MainActor
    private func makeMC() -> MCClient {
        MCClient(clientKey: "test-key", lobbyURL: baseURL, deviceId: "test-device")
    }

    @MainActor
    private func makeAttachedMC() -> MCClient {
        let mc = makeMC()
        let node = LobbyNode(
            id: "test-node", parentId: nil, name: "Test", slug: "test", kind: .location,
            metadata: [:],
            mc: .init(url: baseURL.absoluteString, isRunning: true, startedAt: nil),
            operator: nil,
            live: .init(activeSessions: 0, activeRaces: 0, activePostings: 0)
        )
        mc.attach(to: node)
        return mc
    }

    // MARK: - Public endpoints

    @MainActor
    @Test("GET /api/pitwall/laps returns array (may require MC attachment)", .disabled("live network test — run manually"))
    func fetchLaps() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let laps = try await api.laps(filter: LapFilter(limit: 10))
        #expect(laps.count >= 0)
        for lap in laps {
            #expect(!lap.driverName.isEmpty)
            #expect(lap.bestLapMs > 0)
        }
    }

    @MainActor
    @Test("GET /api/pitwall/competitions returns array", .disabled("live network test — run manually"))
    func fetchCompetitions() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let competitions = try await api.competitions()
        #expect(competitions.count >= 0)
    }

    @Test("LapFilter builds correct query items")
    func lapFilterQueryItems() {
        let filter = LapFilter(
            track: "brands-hatch",
            vehicleClass: "gt3",
            driverName: "Tom",
            period: "today",
            limit: 25
        )
        let items = filter.queryItems
        #expect(items.contains(URLQueryItem(name: "track", value: "brands-hatch")))
        #expect(items.contains(URLQueryItem(name: "vehicle_class", value: "gt3")))
        #expect(items.contains(URLQueryItem(name: "driver_name", value: "Tom")))
        #expect(items.contains(URLQueryItem(name: "period", value: "today")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "25")))
    }

    @Test("SessionFilter builds correct query items")
    func sessionFilterQueryItems() {
        let filter = SessionFilter(rigId: "rig-01", status: .active, limit: 5)
        let items = filter.queryItems
        #expect(items.contains(URLQueryItem(name: "rig_id", value: "rig-01")))
        #expect(items.contains(URLQueryItem(name: "status", value: "active")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "5")))
    }

    @Test("Empty SessionFilter has no query items")
    func emptySessionFilter() {
        let filter = SessionFilter()
        #expect(filter.queryItems.isEmpty)
    }

    @Test("Empty LapFilter has no query items")
    func emptyLapFilter() {
        let filter = LapFilter()
        #expect(filter.queryItems.isEmpty)
    }

    // MARK: - Admin endpoints (require attachment)

    @MainActor
    @Test("rigs() throws notAttached when no MC attached")
    func rigsRequiresAttachment() async throws {
        let mc = makeMC()  // no attachment
        let api = PitWallAPI(mc: mc)

        await #expect(throws: APIError.self) {
            try await api.rigs()
        }
    }

    @MainActor
    @Test("serverStatus() throws notAttached when no MC attached")
    func serverStatusRequiresAttachment() async throws {
        let mc = makeMC()  // no attachment
        let api = PitWallAPI(mc: mc)

        await #expect(throws: APIError.self) {
            try await api.serverStatus()
        }
    }

    // MARK: - APIError descriptions

    @Test("APIError errorDescription returns non-empty strings")
    func apiErrorDescriptions() {
        let errors: [APIError] = [
            .notAttached,
            .badURL,
            .networkError(URLError(.timedOut)),
            .serverError(500, "Internal Server Error"),
            .decodingError(NSError(domain: "test", code: 0)),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    // MARK: - StartSessionParams body

    @Test("StartSessionParams body includes required fields")
    func startSessionParamsBody() {
        let params = StartSessionParams(
            rigId: "rig-01",
            driverName: "Tom",
            durationMinutes: 30,
            driverEmail: "tom@example.com"
        )
        let body = params.body
        #expect(body["rig_id"] as? String == "rig-01")
        #expect(body["driver_name"] as? String == "Tom")
        #expect(body["duration_minutes"] as? Int == 30)
        #expect(body["check_in_method"] as? String == "operator")
        #expect(body["driver_email"] as? String == "tom@example.com")
    }

    @Test("CreateCompetitionParams body includes required fields")
    func createCompetitionParamsBody() {
        let params = CreateCompetitionParams(
            name: "Test Cup",
            type: .fastestLap,
            trackId: "brands-hatch",
            vehicleClass: "gt3",
            maxParticipants: 8
        )
        let body = params.body
        #expect(body["name"] as? String == "Test Cup")
        #expect(body["type"] as? String == "fastest_lap")
        #expect(body["track_id"] as? String == "brands-hatch")
        #expect(body["vehicle_class"] as? String == "gt3")
        #expect(body["max_participants"] as? Int == 8)
    }
}
