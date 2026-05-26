import Foundation

struct Rig: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let location: String
    let status: RigStatus
    let hardwareProfile: String?
    let ipAddress: String?
    let qrCodeId: String
    let currentSessionId: String?
    let createdAt: Int
    let updatedAt: Int

    enum RigStatus: String, Codable, Sendable {
        case available
        case occupied
        case maintenance
        case offline
    }
}

/// Extended rig shape as it appears inside a LiveState SSE snapshot.
struct LiveRig: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let label: String
    let location: String
    let status: Rig.RigStatus
    let hardwareProfile: String?
    let ipAddress: String?
    let qrCodeId: String
    let currentSessionId: String?
    let createdAt: Int
    let updatedAt: Int

    // Live telemetry fields (only present during an active session)
    let driverName: String?
    let bestLapMs: Int?
    let lastLapMs: Int?
    let currentLap: Int?
    let position: Int?
    let gapToLeaderMs: Int?
    let pitStatus: PitStatus?

    enum PitStatus: String, Codable, Sendable {
        case onTrack = "on_track"
        case inPit = "in_pit"
        case pitEntry = "pit_entry"
        case pitExit = "pit_exit"
    }
}
