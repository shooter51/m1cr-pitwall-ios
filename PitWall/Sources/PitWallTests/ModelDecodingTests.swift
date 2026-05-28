import Testing
import Foundation
@testable import PitWall

// MARK: - Model decoding tests
// These test that our Codable models correctly decode real API response shapes.

@Suite("Model Decoding")
struct ModelDecodingTests {

    // MARK: - Rig

    @Test("Rig decodes all fields")
    func rigDecoding() throws {
        let json = """
        {
          "id": "rig-01",
          "label": "RIG 1",
          "org_id": "00000000-0000-0000-0000-000000000001",
          "status": "occupied",
          "hardware_profile": {"ram_gb": 32, "gpu": "RTX 4090"},
          "ip_address": "192.168.1.101",
          "qr_code_id": "rig-01-qr",
          "current_session_id": "session-abc",
          "created_at": "2023-11-14T20:13:20Z",
          "updated_at": "2023-11-14T20:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let rig = try decoder.decode(Rig.self, from: json)

        #expect(rig.id == "rig-01")
        #expect(rig.label == "RIG 1")
        #expect(rig.orgId == "00000000-0000-0000-0000-000000000001")
        #expect(rig.status == .occupied)
        #expect(rig.hardwareProfile != nil)
        #expect(rig.ipAddress == "192.168.1.101")
        #expect(rig.qrCodeId == "rig-01-qr")
        #expect(rig.currentSessionId == "session-abc")
        #expect(rig.createdAt == "2023-11-14T20:13:20Z")
        #expect(rig.updatedAt == "2023-11-14T20:30:00Z")
    }

    @Test("Rig decodes all status values")
    func rigStatusDecoding() throws {
        let statuses: [(String, Rig.RigStatus)] = [
            ("available", .available),
            ("occupied", .occupied),
            ("maintenance", .maintenance),
            ("offline", .offline),
        ]

        let decoder = snakeDecoder()

        for (raw, expected) in statuses {
            let json = rigJSON(status: raw)
            let rig = try decoder.decode(Rig.self, from: json)
            #expect(rig.status == expected, "Status \(raw) should decode to \(expected)")
        }
    }

    @Test("Rig decodes null optional fields")
    func rigNullOptionals() throws {
        let json = rigJSON(status: "available", nullable: true)
        let decoder = snakeDecoder()
        let rig = try decoder.decode(Rig.self, from: json)
        #expect(rig.hardwareProfile == nil)
        #expect(rig.ipAddress == nil)
        #expect(rig.qrCodeId == nil)
        #expect(rig.currentSessionId == nil)
    }

    // MARK: - LiveRig

    @Test("LiveRig decodes telemetry fields")
    func liveRigDecoding() throws {
        let json = """
        {
          "id": "rig-01",
          "label": "RIG 1",
          "org_id": "00000000-0000-0000-0000-000000000001",
          "status": "occupied",
          "hardware_profile": null,
          "ip_address": null,
          "qr_code_id": "qr-01",
          "current_session_id": "s-01",
          "created_at": "2023-11-14T20:13:20Z",
          "updated_at": "2023-11-14T20:30:00Z",
          "driver_name": "TOM GIBSON",
          "best_lap_ms": 78432,
          "last_lap_ms": 79012,
          "current_lap": 8,
          "position": 1,
          "gap_to_leader_ms": 0,
          "pit_status": "on_track"
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let rig = try decoder.decode(LiveRig.self, from: json)

        #expect(rig.driverName == "TOM GIBSON")
        #expect(rig.bestLapMs == 78432)
        #expect(rig.lastLapMs == 79012)
        #expect(rig.currentLap == 8)
        #expect(rig.position == 1)
        #expect(rig.gapToLeaderMs == 0)
        #expect(rig.pitStatus == .onTrack)
    }

    @Test("LiveRig pit status values decode correctly")
    func liveRigPitStatus() throws {
        let cases: [(String, LiveRig.PitStatus)] = [
            ("on_track", .onTrack),
            ("in_pit", .inPit),
            ("pit_entry", .pitEntry),
            ("pit_exit", .pitExit),
        ]

        let decoder = snakeDecoder()
        for (raw, expected) in cases {
            let json = liveRigJSON(pitStatus: raw)
            let rig = try decoder.decode(LiveRig.self, from: json)
            #expect(rig.pitStatus == expected, "pit_status \(raw) should decode to \(expected)")
        }
    }

    // MARK: - Session

    @Test("Session decodes all fields")
    func sessionDecoding() throws {
        let json = """
        {
          "id": "session-01",
          "rig_id": "rig-01",
          "booking_id": null,
          "driver_name": "Tom Gibson",
          "driver_email": "tom@example.com",
          "driver_phone": null,
          "check_in_method": "operator",
          "status": "active",
          "started_at": "2023-11-14T20:13:20Z",
          "ended_at": null,
          "duration_minutes": 30,
          "steam_participant_id": 12345,
          "experience_level": "intermediate",
          "metadata": null
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let session = try decoder.decode(Session.self, from: json)

        #expect(session.id == "session-01")
        #expect(session.rigId == "rig-01")
        #expect(session.driverName == "Tom Gibson")
        #expect(session.driverEmail == "tom@example.com")
        #expect(session.checkInMethod == .operator)
        #expect(session.status == .active)
        #expect(session.startedAt == "2023-11-14T20:13:20Z")
        #expect(session.endedAt == nil)
        #expect(session.durationMinutes == 30)
        #expect(session.steamParticipantId == 12345)
        #expect(session.experienceLevel == .intermediate)
    }

    @Test("Session status values decode correctly")
    func sessionStatus() throws {
        let cases: [(String, Session.SessionStatus)] = [
            ("active", .active),
            ("completed", .completed),
            ("expired", .expired),
            ("cancelled", .cancelled),
        ]
        let decoder = snakeDecoder()
        for (raw, expected) in cases {
            let json = sessionJSON(status: raw)
            let s = try decoder.decode(Session.self, from: json)
            #expect(s.status == expected)
        }
    }

    // MARK: - LapTime

    @Test("LapTime decodes all fields")
    func lapTimeDecoding() throws {
        let json = """
        {
          "id": "lap-01",
          "session_id": "session-01",
          "rig_id": "rig-01",
          "driver_name": "Tom Gibson",
          "track_id": "brands-hatch",
          "track_name": "Brands Hatch Indy",
          "vehicle_class": "gt3",
          "vehicle_name": "BMW M4 GT3",
          "lap_number": 5,
          "lap_time_ms": 78432,
          "sector_1_ms": 26100,
          "sector_2_ms": 27500,
          "sector_3_ms": 24832,
          "is_valid": 1,
          "is_personal_best": 1,
          "weather_conditions": "clear",
          "recorded_at": 1700001234
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let lap = try decoder.decode(LapTime.self, from: json)

        #expect(lap.id == "lap-01")
        #expect(lap.lapTimeMs == 78432)
        #expect(lap.sector1Ms == 26100)
        #expect(lap.sector2Ms == 27500)
        #expect(lap.sector3Ms == 24832)
        #expect(lap.isValid == 1)
        #expect(lap.isPersonalBest == 1)
        #expect(lap.isValidBool == true)
        #expect(lap.isPersonalBestBool == true)
    }

    @Test("LapTime handles null sectors")
    func lapTimeNullSectors() throws {
        let json = """
        {
          "id": "lap-02",
          "session_id": "s-01",
          "rig_id": "rig-01",
          "driver_name": "Alex",
          "track_id": "snetterton",
          "track_name": "Snetterton",
          "vehicle_class": "gt4",
          "vehicle_name": "Porsche Cayman",
          "lap_number": 1,
          "lap_time_ms": 92100,
          "sector_1_ms": null,
          "sector_2_ms": null,
          "sector_3_ms": null,
          "is_valid": 0,
          "is_personal_best": 0,
          "weather_conditions": null,
          "recorded_at": 1700002000
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let lap = try decoder.decode(LapTime.self, from: json)

        #expect(lap.sector1Ms == nil)
        #expect(lap.isValidBool == false)
    }

    // MARK: - Competition

    @Test("Competition decodes all fields")
    func competitionDecoding() throws {
        let json = """
        {
          "id": "comp-01",
          "name": "Friday Night Fastest Lap",
          "type": "fastest_lap",
          "status": "active",
          "track_id": "brands-hatch",
          "track_name": "Brands Hatch Indy",
          "vehicle_class": "gt3",
          "vehicle_locked": null,
          "rules": null,
          "starts_at": "2026-05-28T00:00:00Z",
          "ends_at": "2026-05-28T01:00:00Z",
          "max_participants": 10,
          "prize_description": "£50 voucher",
          "created_at": "2023-11-14T20:13:20Z"
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let comp = try decoder.decode(Competition.self, from: json)

        #expect(comp.id == "comp-01")
        #expect(comp.type == .fastestLap)
        #expect(comp.status == .active)
        #expect(comp.maxParticipants == 10)
        #expect(comp.prizeDescription == "£50 voucher")
        #expect(comp.startsAt == "2026-05-28T00:00:00Z")
        #expect(comp.createdAt == "2023-11-14T20:13:20Z")
    }

    @Test("Competition type values decode correctly")
    func competitionTypes() throws {
        let cases: [(String, Competition.CompetitionType)] = [
            ("fastest_lap", .fastestLap),
            ("race", .race),
            ("endurance", .endurance),
            ("time_attack", .timeAttack),
        ]
        let decoder = snakeDecoder()
        for (raw, expected) in cases {
            let json = competitionJSON(type: raw)
            let c = try decoder.decode(Competition.self, from: json)
            #expect(c.type == expected)
        }
    }

    // MARK: - ServerStatus

    @Test("ServerStatus decodes all EC2 states")
    func serverStatusDecoding() throws {
        let cases: [(String, ServerStatus.EC2Status)] = [
            ("running", .running),
            ("stopped", .stopped),
            ("starting", .starting),
            ("stopping", .stopping),
        ]
        let decoder = snakeDecoder()
        for (raw, expected) in cases {
            let json = """
            {"status": "\(raw)", "ip": null}
            """.data(using: .utf8)!
            let status = try decoder.decode(ServerStatus.self, from: json)
            #expect(status.status == expected)
        }
    }

    @Test("ServerStatus transitioning states are identified")
    func serverStatusTransitioning() {
        #expect(ServerStatus.EC2Status.starting.isTransitioning == true)
        #expect(ServerStatus.EC2Status.stopping.isTransitioning == true)
        #expect(ServerStatus.EC2Status.running.isTransitioning == false)
        #expect(ServerStatus.EC2Status.stopped.isTransitioning == false)
    }

    // MARK: - LiveState

    @Test("LiveState decodes full snapshot")
    func liveStateDecoding() throws {
        let json = fullLiveStateJSON().data(using: .utf8)!
        let decoder = snakeDecoder()
        let state = try decoder.decode(LiveState.self, from: json)

        #expect(state.ts == 1700001234567)
        #expect(state.track.id == "brands-hatch")
        #expect(state.track.weather == "Clear")
        #expect(state.session.phase == "race")
        #expect(state.session.timeLeftS == 847)
        #expect(state.rigs.count == 2)
        #expect(state.competition != nil)
        #expect(state.broadcast.mode == .auto)
        #expect(state.server.status == .running)
    }

    @Test("LiveState decodes without competition")
    func liveStateNoCompetition() throws {
        let json = """
        {
          "ts": 1700000000,
          "track": {"id": "t1", "name": "Test", "weather": "Cloudy"},
          "session": {"phase": "practice", "time_left_s": 0},
          "rigs": [],
          "competition": null,
          "broadcast": {"mode": "off", "focus": null, "scene": null},
          "server": {"status": "stopped"}
        }
        """.data(using: .utf8)!

        let decoder = snakeDecoder()
        let state = try decoder.decode(LiveState.self, from: json)
        #expect(state.competition == nil)
        #expect(state.server.status == .stopped)
    }

    // MARK: - MockRigProvider sanity check

    @Test("MockRigProvider produces valid rigs")
    func mockRigProviderValid() {
        let rigs = MockRigProvider.rigs
        #expect(rigs.count == 10)
        #expect(rigs.first?.id == "rig-01")
        #expect(rigs.first?.status == .occupied)

        // At least one available rig
        let available = rigs.filter { $0.status == .available }
        #expect(available.count >= 1)

        // Mock LiveState is consistent
        let state = MockRigProvider.liveState
        #expect(state.rigs.count == 10)
        #expect(state.server.status == .running)
    }

    // MARK: - Helpers

    private func snakeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func rigJSON(status: String, nullable: Bool = false) -> Data {
        """
        {
          "id": "rig-01",
          "label": "RIG 1",
          "org_id": "00000000-0000-0000-0000-000000000001",
          "status": "\(status)",
          "hardware_profile": \(nullable ? "null" : "{\"ram_gb\": 32}"),
          "ip_address": \(nullable ? "null" : "\"192.168.1.101\""),
          "qr_code_id": \(nullable ? "null" : "\"rig-01-qr\""),
          "current_session_id": \(nullable ? "null" : "\"session-abc\""),
          "created_at": "2023-11-14T20:13:20Z",
          "updated_at": "2023-11-14T20:30:00Z"
        }
        """.data(using: .utf8)!
    }

    private func liveRigJSON(pitStatus: String) -> Data {
        """
        {
          "id": "rig-01",
          "label": "RIG 1",
          "org_id": "00000000-0000-0000-0000-000000000001",
          "status": "occupied",
          "hardware_profile": null,
          "ip_address": null,
          "qr_code_id": "qr-01",
          "current_session_id": "s-01",
          "created_at": "2023-11-14T20:13:20Z",
          "updated_at": "2023-11-14T20:30:00Z",
          "driver_name": "TOM",
          "best_lap_ms": 78000,
          "last_lap_ms": 79000,
          "current_lap": 5,
          "position": 2,
          "gap_to_leader_ms": 1000,
          "pit_status": "\(pitStatus)"
        }
        """.data(using: .utf8)!
    }

    private func sessionJSON(status: String) -> Data {
        """
        {
          "id": "s-01",
          "rig_id": "rig-01",
          "booking_id": null,
          "driver_name": "Tom",
          "driver_email": null,
          "driver_phone": null,
          "check_in_method": "operator",
          "status": "\(status)",
          "started_at": "2023-11-14T20:13:20Z",
          "ended_at": null,
          "duration_minutes": 30,
          "steam_participant_id": null,
          "experience_level": null,
          "metadata": null
        }
        """.data(using: .utf8)!
    }

    private func competitionJSON(type: String) -> Data {
        """
        {
          "id": "c-01",
          "name": "Test Comp",
          "type": "\(type)",
          "status": "scheduled",
          "track_id": "t-01",
          "track_name": "Test Track",
          "vehicle_class": "gt3",
          "vehicle_locked": null,
          "rules": null,
          "starts_at": null,
          "ends_at": null,
          "max_participants": null,
          "prize_description": null,
          "created_at": "2023-11-14T20:13:20Z"
        }
        """.data(using: .utf8)!
    }

    private func fullLiveStateJSON() -> String {
        """
        {
          "ts": 1700001234567,
          "track": {"id": "brands-hatch", "name": "Brands Hatch Indy", "weather": "Clear"},
          "session": {"phase": "race", "time_left_s": 847},
          "rigs": [
            {
              "id": "rig-01",
              "label": "RIG 1",
              "org_id": "00000000-0000-0000-0000-000000000001",
              "status": "occupied",
              "hardware_profile": null,
              "ip_address": null,
              "qr_code_id": "qr-01",
              "current_session_id": "s-01",
              "created_at": "2023-11-14T20:13:20Z",
              "updated_at": "2023-11-14T20:30:00Z",
              "driver_name": "TOM GIBSON",
              "best_lap_ms": 78432,
              "last_lap_ms": 79012,
              "current_lap": 8,
              "position": 1,
              "gap_to_leader_ms": 0,
              "pit_status": "on_track"
            },
            {
              "id": "rig-02",
              "label": "RIG 2",
              "org_id": "00000000-0000-0000-0000-000000000001",
              "status": "available",
              "hardware_profile": null,
              "ip_address": null,
              "qr_code_id": "qr-02",
              "current_session_id": null,
              "created_at": "2023-11-14T20:13:20Z",
              "updated_at": "2023-11-14T20:30:00Z",
              "driver_name": null,
              "best_lap_ms": null,
              "last_lap_ms": null,
              "current_lap": null,
              "position": null,
              "gap_to_leader_ms": null,
              "pit_status": null
            }
          ],
          "competition": {
            "id": "comp-01",
            "name": "Friday Night Fastest Lap",
            "type": "fastest_lap",
            "status": "active",
            "track_id": "brands-hatch",
            "track_name": "Brands Hatch Indy",
            "vehicle_class": "gt3",
            "vehicle_locked": null,
            "rules": null,
            "starts_at": "2026-05-28T00:00:00Z",
            "ends_at": "2026-05-28T01:00:00Z",
            "max_participants": 10,
            "prize_description": "£50 voucher",
            "created_at": "2023-11-14T20:13:20Z"
          },
          "broadcast": {"mode": "auto", "focus": null, "scene": null},
          "server": {"status": "running"}
        }
        """
    }
}
