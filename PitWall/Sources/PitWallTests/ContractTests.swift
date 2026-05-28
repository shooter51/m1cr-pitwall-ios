import Testing
import Foundation
@testable import PitWall

// MARK: - Contract Tests
// Verify that iOS models decode real backend response shapes exactly.
// Each test loads a fixture JSON file and decodes through the same decoder the app uses.

@Suite("Contract Tests")
struct ContractTests {

    private func snakeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func fixture(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            Issue.record("Missing fixture: \(name)")
            throw ContractError.missingFixture(name)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Rigs

    @Test("GET /api/pitwall/rigs — fixture decodes via wrapper")
    func rigsResponseDecodes() throws {
        struct RigsResponse: Decodable { let rigs: [Rig] }
        let data = try fixture(named: "rigs-response.json")
        let response = try snakeDecoder().decode(RigsResponse.self, from: data)
        #expect(response.rigs.count == 1)
        let rig = response.rigs[0]
        #expect(rig.id == "rig-01")
        #expect(rig.label == "RIG 1")
        #expect(rig.orgId == "00000000-0000-0000-0000-000000000001")
        #expect(rig.status == .occupied)
        #expect(rig.hardwareProfile != nil)
        #expect(rig.ipAddress == "192.168.1.101")
        #expect(rig.qrCodeId == "550e8400-e29b-41d4-a716-446655440001")
        #expect(rig.currentSessionId == "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
        #expect(rig.createdAt == "2026-01-15T09:00:00Z")
        #expect(rig.updatedAt == "2026-05-26T14:32:00Z")
    }

    // MARK: - Sessions

    @Test("GET /api/pitwall/sessions — fixture decodes via wrapper")
    func sessionsResponseDecodes() throws {
        struct SessionsResponse: Decodable { let sessions: [Session] }
        let data = try fixture(named: "sessions-response.json")
        let response = try snakeDecoder().decode(SessionsResponse.self, from: data)
        #expect(response.sessions.count == 1)
        let session = response.sessions[0]
        #expect(session.id == "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
        #expect(session.rigId == "rig-01")
        #expect(session.driverName == "Tom Gibson")
        #expect(session.driverEmail == "tom@example.com")
        #expect(session.checkInMethod == .operator)
        #expect(session.status == .active)
        #expect(session.startedAt == "2026-05-26T14:00:00Z")
        #expect(session.endedAt == nil)
        #expect(session.durationMinutes == 30)
        #expect(session.experienceLevel == .intermediate)
    }

    // MARK: - Laps (leaderboard)

    @Test("GET /api/pitwall/laps — fixture decodes leaderboard rows")
    func lapsResponseDecodes() throws {
        struct LapsResponse: Decodable { let rows: [LeaderboardEntry] }
        let data = try fixture(named: "laps-response.json")
        let response = try snakeDecoder().decode(LapsResponse.self, from: data)
        #expect(response.rows.count == 1)
        let entry = response.rows[0]
        #expect(entry.driverName == "Tom Gibson")
        #expect(entry.bestLapMs == 95432)
        #expect(entry.trackName == "Laguna Seca")
        #expect(entry.vehicleClass == "GT3")
        #expect(entry.lastAt == "2026-05-26T14:15:00Z")
    }

    // MARK: - Competitions

    @Test("GET /api/pitwall/competitions — fixture decodes via wrapper")
    func competitionsResponseDecodes() throws {
        struct CompetitionsResponse: Decodable { let competitions: [Competition] }
        let data = try fixture(named: "competitions-response.json")
        let response = try snakeDecoder().decode(CompetitionsResponse.self, from: data)
        #expect(response.competitions.count == 1)
        let comp = response.competitions[0]
        #expect(comp.id == "c1f4a7b8-9d2e-4f3a-8b1c-5e6d7a8b9c0d")
        #expect(comp.name == "Friday Night GT3 Challenge")
        #expect(comp.type == .fastestLap)
        #expect(comp.status == .active)
        #expect(comp.trackId == "laguna_seca")
        #expect(comp.vehicleClass == "GT3")
        #expect(comp.rules != nil)
        #expect(comp.startsAt == "2026-05-28T00:00:00Z")
        #expect(comp.endsAt == "2026-05-28T01:00:00Z")
        #expect(comp.createdAt == "2026-05-20T10:00:00Z")
    }

    // MARK: - Lobby Nodes

    @Test("GET /lobby/nodes — fixture decodes LobbyNode list")
    func lobbyNodesResponseDecodes() throws {
        struct NodesResponse: Decodable { let nodes: [LobbyNode] }
        let data = try fixture(named: "lobby-nodes-response.json")
        let response = try snakeDecoder().decode(NodesResponse.self, from: data)
        #expect(response.nodes.count == 1)
        let node = response.nodes[0]
        #expect(node.id == "00000000-0000-0000-0000-000000000001")
        #expect(node.name == "Laguna Seca")
        #expect(node.slug == "laguna-seca")
        #expect(node.kind == .location)
        #expect(node.mc.isRunning == true)
        #expect(node.mc.url == "https://pitwall.m1circuit.com")
        #expect(node.operator?.deviceId == "device-abc123")
        #expect(node.live.activeSessions == 3)
        #expect(node.live.activePostings == 1)
    }

    // MARK: - Server Status

    @Test("GET /api/pitwall/server-control — fixture decodes ServerStatus")
    func serverStatusResponseDecodes() throws {
        let data = try fixture(named: "server-status-response.json")
        let status = try snakeDecoder().decode(ServerStatus.self, from: data)
        #expect(status.status == .running)
        #expect(status.ip == "10.0.0.1")
    }

    // MARK: - Live State (SSE snapshot)

    @Test("SSE live-state — fixture decodes LiveState")
    func liveStateDecodes() throws {
        let data = try fixture(named: "live-state.json")
        let state = try snakeDecoder().decode(LiveState.self, from: data)
        #expect(state.ts == 1748267520000)
        #expect(state.track.id == "laguna_seca")
        #expect(state.track.name == "Laguna Seca")
        #expect(state.track.weather == "Clear")
        #expect(state.session.phase == "race")
        #expect(state.session.timeLeftS == 847)
        #expect(state.rigs.count == 2)
        let occupiedRig = state.rigs[0]
        #expect(occupiedRig.id == "rig-01")
        #expect(occupiedRig.driverName == "TOM GIBSON")
        #expect(occupiedRig.bestLapMs == 95432)
        #expect(occupiedRig.pitStatus == .onTrack)
        let emptyRig = state.rigs[1]
        #expect(emptyRig.status == .available)
        #expect(emptyRig.driverName == nil)
        #expect(state.competition?.id == "c1f4a7b8-9d2e-4f3a-8b1c-5e6d7a8b9c0d")
        #expect(state.broadcast.mode == .auto)
        #expect(state.server.status == .running)
    }

    // MARK: - Race Wall

    @Test("GET /api/race-wall — fixture decodes RacePosting list")
    func raceWallResponseDecodes() throws {
        struct PostingsResponse: Decodable { let postings: [RacePosting] }
        let data = try fixture(named: "race-wall-response.json")
        let response = try snakeDecoder().decode(PostingsResponse.self, from: data)
        #expect(response.postings.count == 1)
        let posting = response.postings[0]
        #expect(posting.id == "d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f60")
        #expect(posting.trackName == "Laguna Seca")
        #expect(posting.vehicleClass == "GT3")
        #expect(posting.status == .live)
        #expect(posting.slotTotal == 8)
        #expect(posting.slotOpen == 5)
        #expect(posting.sourceName == "Laguna Seca")
    }

    // MARK: - Session Create Response

    @Test("POST /api/pitwall/sessions — fixture decodes SessionCreateResponse")
    func sessionCreateResponseDecodes() throws {
        let data = try fixture(named: "session-create-response.json")
        let response = try snakeDecoder().decode(SessionCreateResponse.self, from: data)
        #expect(response.sessionId == "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")
        #expect(response.rigId == "rig-01")
        #expect(response.durationMinutes == 15)
    }

    // MARK: - Competition Create Response

    @Test("POST /api/pitwall/competitions — fixture decodes CompetitionCreateResponse")
    func competitionCreateResponseDecodes() throws {
        let data = try fixture(named: "competition-create-response.json")
        let response = try snakeDecoder().decode(CompetitionCreateResponse.self, from: data)
        #expect(response.id == "c1f4a7b8-9d2e-4f3a-8b1c-5e6d7a8b9c0d")
        #expect(response.startsAt == "2026-05-28T00:00:00Z")
        #expect(response.endsAt == "2026-05-28T01:00:00Z")
    }
}

// MARK: - Error type

enum ContractError: Error {
    case missingFixture(String)
}
