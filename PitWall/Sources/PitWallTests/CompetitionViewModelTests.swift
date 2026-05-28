import Testing
import Foundation
@testable import PitWall

// MARK: - CompetitionViewModel tests

@Suite("CompetitionViewModel")
struct CompetitionViewModelTests {
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

    // MARK: - CreateCompetitionParams

    @Test("CreateCompetitionParams body includes all required fields")
    func createParamsRequiredFields() {
        let params = CreateCompetitionParams(
            name: "Test Sprint Cup",
            type: .fastestLap,
            trackId: "brands-hatch",
            vehicleClass: "GT3"
        )
        let body = params.body
        #expect(body["name"] as? String == "Test Sprint Cup")
        #expect(body["type"] as? String == "fastest_lap")
        #expect(body["track_id"] as? String == "brands-hatch")
        #expect(body["vehicle_class"] as? String == "GT3")
    }

    @Test("CreateCompetitionParams body omits nil optional fields")
    func createParamsOptionalFieldsOmitted() {
        let params = CreateCompetitionParams(
            name: "Minimalist Cup",
            type: .race,
            trackId: "silverstone",
            vehicleClass: "GT4"
        )
        let body = params.body
        #expect(body["vehicle_locked"] == nil)
        #expect(body["max_participants"] == nil)
        #expect(body["prize_description"] == nil)
        #expect(body["starts_at"] == nil)
        #expect(body["ends_at"] == nil)
    }

    @Test("CreateCompetitionParams body includes optional fields when set")
    func createParamsOptionalFieldsIncluded() {
        let params = CreateCompetitionParams(
            name: "Premium Cup",
            type: .endurance,
            trackId: "spa",
            vehicleClass: "LMP",
            vehicleLocked: "Ferrari 499P",
            maxParticipants: 12,
            prizeDescription: "£100 voucher",
            startsAt: 1_700_000_000,
            endsAt: 1_700_003_600
        )
        let body = params.body
        #expect(body["vehicle_locked"] as? String == "Ferrari 499P")
        #expect(body["max_participants"] as? Int == 12)
        #expect(body["prize_description"] as? String == "£100 voucher")
        #expect(body["starts_at"] as? Int == 1_700_000_000)
        #expect(body["ends_at"] as? Int == 1_700_003_600)
    }

    // MARK: - CompetitionType

    @Test("CompetitionType raw values are correct API strings")
    func competitionTypeRawValues() {
        #expect(Competition.CompetitionType.fastestLap.rawValue == "fastest_lap")
        #expect(Competition.CompetitionType.race.rawValue == "race")
        #expect(Competition.CompetitionType.endurance.rawValue == "endurance")
        #expect(Competition.CompetitionType.timeAttack.rawValue == "time_attack")
    }

    @Test("CompetitionType CaseIterable contains all 4 cases")
    func competitionTypeAllCases() {
        #expect(Competition.CompetitionType.allCases.count == 4)
    }

    @Test("CompetitionType displayName returns human-readable strings")
    func competitionTypeDisplayName() {
        #expect(Competition.CompetitionType.fastestLap.displayName == "Fastest Lap")
        #expect(Competition.CompetitionType.race.displayName == "Race")
        #expect(Competition.CompetitionType.endurance.displayName == "Endurance")
        #expect(Competition.CompetitionType.timeAttack.displayName == "Time Attack")
    }

    // MARK: - CompetitionStatus

    @Test("CompetitionStatus raw values are correct API strings")
    func competitionStatusRawValues() {
        #expect(Competition.CompetitionStatus.scheduled.rawValue == "scheduled")
        #expect(Competition.CompetitionStatus.active.rawValue == "active")
        #expect(Competition.CompetitionStatus.completed.rawValue == "completed")
        #expect(Competition.CompetitionStatus.cancelled.rawValue == "cancelled")
    }

    // MARK: - API integration

    @MainActor
    @Test("GET /api/pitwall/competitions returns array", .disabled("live network test — run manually"))
    func fetchCompetitionsFromAPI() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)

        let competitions = try await api.competitions()
        #expect(competitions.count >= 0)
        for comp in competitions {
            #expect(!comp.id.isEmpty)
            #expect(!comp.name.isEmpty)
            #expect(!comp.trackId.isEmpty)
            #expect(!comp.vehicleClass.isEmpty)
        }
    }

    @Test("Competition model decodes all required fields")
    func competitionModelDecoding() throws {
        let json = """
        {
            "id": "comp-test-01",
            "name": "Test Cup",
            "type": "fastest_lap",
            "status": "active",
            "track_id": "brands-hatch",
            "track_name": "Brands Hatch Indy",
            "vehicle_class": "GT3",
            "vehicle_locked": null,
            "rules": null,
            "starts_at": null,
            "ends_at": null,
            "max_participants": 10,
            "prize_description": "£50 voucher",
            "created_at": "2023-11-14T20:13:20Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let comp = try decoder.decode(Competition.self, from: json)

        #expect(comp.id == "comp-test-01")
        #expect(comp.name == "Test Cup")
        #expect(comp.type == .fastestLap)
        #expect(comp.status == .active)
        #expect(comp.trackId == "brands-hatch")
        #expect(comp.trackName == "Brands Hatch Indy")
        #expect(comp.vehicleClass == "GT3")
        #expect(comp.maxParticipants == 10)
        #expect(comp.prizeDescription == "£50 voucher")
        #expect(comp.createdAt == "2023-11-14T20:13:20Z")
    }

    @MainActor
    @Test("CompetitionViewModel loads competitions from API", .disabled("live network test — run manually"))
    func viewModelLoadCompetitions() async {
        let mc = makeAttachedMC()
        let vm = CompetitionViewModel(mc: mc)

        await vm.loadCompetitions()

        // Should not crash — either loaded data or got an acceptable error
        #expect(vm.isLoading == false)
    }
}
