import Testing
import Foundation
@testable import PitWall

// MARK: - LapTime tests
// Tests lap model decoding, LapFilter query item building, and API queries.

@Suite("LapTime")
struct LapTimeTests {
    let baseURL = URL(string: "https://pitwall.m1circuit.com")!

    @MainActor
    private func makeAttachedMC() -> MCClient {
        let mc = MCClient(clientKey: "test-key", lobbyURL: baseURL, deviceId: "test-device")
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

    // MARK: - LapFilter query items

    @Test("LapFilter with all fields builds all query items")
    func lapFilterAllFields() {
        let filter = LapFilter(
            track: "brands-hatch",
            vehicleClass: "GT3",
            driverName: "Tom Gibson",
            period: "today",
            limit: 50
        )
        let items = filter.queryItems
        #expect(items.contains(URLQueryItem(name: "track", value: "brands-hatch")))
        #expect(items.contains(URLQueryItem(name: "vehicle_class", value: "GT3")))
        #expect(items.contains(URLQueryItem(name: "driver_name", value: "Tom Gibson")))
        #expect(items.contains(URLQueryItem(name: "period", value: "today")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "50")))
        #expect(items.count == 5)
    }

    @Test("LapFilter with no fields produces empty query items")
    func lapFilterEmpty() {
        let filter = LapFilter()
        #expect(filter.queryItems.isEmpty)
    }

    @Test("LapFilter with only track produces single query item")
    func lapFilterTrackOnly() {
        let filter = LapFilter(track: "silverstone")
        let items = filter.queryItems
        #expect(items.count == 1)
        #expect(items[0].name == "track")
        #expect(items[0].value == "silverstone")
    }

    @Test("LapFilter limit converts to string correctly")
    func lapFilterLimitToString() {
        let filter = LapFilter(limit: 999)
        let items = filter.queryItems
        let limitItem = items.first { $0.name == "limit" }
        #expect(limitItem?.value == "999")
    }

    // MARK: - LapTime model

    @Test("LapTime model decodes from JSON with all fields")
    func lapTimeFullDecoding() throws {
        let json = """
        {
            "id": "lap-001",
            "session_id": "sess-001",
            "rig_id": "rig-01",
            "driver_name": "Tom Gibson",
            "track_id": "brands-hatch",
            "track_name": "Brands Hatch Indy",
            "vehicle_class": "GT3",
            "vehicle_name": "Ferrari 488",
            "lap_number": 5,
            "lap_time_ms": 78432,
            "sector1_ms": 25000,
            "sector2_ms": 28000,
            "sector3_ms": 25432,
            "is_valid": 1,
            "is_personal_best": 1,
            "weather_conditions": "Clear",
            "recorded_at": 1700000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let lap = try decoder.decode(LapTime.self, from: json)

        #expect(lap.id == "lap-001")
        #expect(lap.sessionId == "sess-001")
        #expect(lap.rigId == "rig-01")
        #expect(lap.driverName == "Tom Gibson")
        #expect(lap.trackId == "brands-hatch")
        #expect(lap.trackName == "Brands Hatch Indy")
        #expect(lap.vehicleClass == "GT3")
        #expect(lap.vehicleName == "Ferrari 488")
        #expect(lap.lapNumber == 5)
        #expect(lap.lapTimeMs == 78_432)
        #expect(lap.sector1Ms == 25_000)
        #expect(lap.sector2Ms == 28_000)
        #expect(lap.sector3Ms == 25_432)
        #expect(lap.isValid == 1)
        #expect(lap.isPersonalBest == 1)
        #expect(lap.weatherConditions == "Clear")
        #expect(lap.recordedAt == 1_700_000_000)
    }

    @Test("LapTime.isValidBool converts 0 and 1 correctly")
    func lapTimeIsValidBool() throws {
        func makeLap(isValid: Int, isPB: Int) throws -> LapTime {
            let json = """
            {
                "id": "lap-x", "session_id": "s", "rig_id": "r",
                "driver_name": "D", "track_id": "t", "track_name": "T",
                "vehicle_class": "c", "vehicle_name": "v",
                "lap_number": 1, "lap_time_ms": 60000,
                "sector1_ms": null, "sector2_ms": null, "sector3_ms": null,
                "is_valid": \(isValid), "is_personal_best": \(isPB),
                "weather_conditions": null, "recorded_at": 1700000000
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(LapTime.self, from: json)
        }

        let valid = try makeLap(isValid: 1, isPB: 1)
        #expect(valid.isValidBool == true)
        #expect(valid.isPersonalBestBool == true)

        let invalid = try makeLap(isValid: 0, isPB: 0)
        #expect(invalid.isValidBool == false)
        #expect(invalid.isPersonalBestBool == false)
    }

    @Test("LapTime decodes with null sectors")
    func lapTimeNullSectors() throws {
        let json = """
        {
            "id": "lap-002",
            "session_id": "sess-002",
            "rig_id": "rig-02",
            "driver_name": "Alex Schmidt",
            "track_id": "spa",
            "track_name": "Circuit de Spa",
            "vehicle_class": "LMP",
            "vehicle_name": "Porsche 963",
            "lap_number": 1,
            "lap_time_ms": 120000,
            "sector1_ms": null,
            "sector2_ms": null,
            "sector3_ms": null,
            "is_valid": 1,
            "is_personal_best": 0,
            "weather_conditions": null,
            "recorded_at": 1700000001
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let lap = try decoder.decode(LapTime.self, from: json)

        #expect(lap.sector1Ms == nil)
        #expect(lap.sector2Ms == nil)
        #expect(lap.sector3Ms == nil)
        #expect(lap.weatherConditions == nil)
    }

    // MARK: - API integration

    @MainActor
    @Test("GET /api/pitwall/laps with period filter", .disabled("live network test — run manually"))
    func fetchLapsWithPeriodFilter() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let laps = try await api.laps(filter: LapFilter(period: "today", limit: 10))
        #expect(laps.count >= 0)
    }

    @MainActor
    @Test("GET /api/pitwall/laps with track filter", .disabled("live network test — run manually"))
    func fetchLapsWithTrackFilter() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let laps = try await api.laps(filter: LapFilter(track: "brands-hatch", limit: 5))
        #expect(laps.count >= 0)
    }

    @MainActor
    @Test("GET /api/pitwall/laps with vehicle class filter", .disabled("live network test — run manually"))
    func fetchLapsWithVehicleClassFilter() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let laps = try await api.laps(filter: LapFilter(vehicleClass: "GT3", limit: 5))
        #expect(laps.count >= 0)
    }

    @MainActor
    @Test("GET /api/pitwall/laps with driver name filter", .disabled("live network test — run manually"))
    func fetchLapsByDriver() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let laps = try await api.laps(filter: LapFilter(driverName: "Tom", limit: 10))
        #expect(laps.count >= 0)
    }

    @MainActor
    @Test("GET /api/pitwall/laps with no filter", .disabled("live network test — run manually"))
    func fetchAllLaps() async throws {
        let mc = makeAttachedMC()
        let api = PitWallAPI(mc: mc)
        let laps = try await api.laps()
        #expect(laps.count >= 0)
    }
}
