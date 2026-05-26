import Foundation
@testable import PitWall

// MARK: - MockRigProvider
// The ONLY mock in the codebase. Provides fake rig data for SwiftUI previews.
// All other tests hit the real API.

enum MockRigProvider {
    static let rigs: [LiveRig] = [
        makeRig(
            id: "rig-01",
            label: "RIG 1",
            status: .occupied,
            driverName: "TOM GIBSON",
            bestLap: 78_432,
            lastLap: 79_012,
            currentLap: 8,
            position: 1,
            gap: 0
        ),
        makeRig(
            id: "rig-02",
            label: "RIG 2",
            status: .occupied,
            driverName: "ALEX SCHMIDT",
            bestLap: 79_210,
            lastLap: 79_890,
            currentLap: 7,
            position: 2,
            gap: 778
        ),
        makeRig(
            id: "rig-03",
            label: "RIG 3",
            status: .available,
            driverName: nil,
            bestLap: nil,
            lastLap: nil,
            currentLap: nil,
            position: nil,
            gap: nil
        ),
        makeRig(
            id: "rig-04",
            label: "RIG 4",
            status: .maintenance,
            driverName: nil,
            bestLap: nil,
            lastLap: nil,
            currentLap: nil,
            position: nil,
            gap: nil
        ),
        makeRig(
            id: "rig-05",
            label: "RIG 5",
            status: .occupied,
            driverName: "SARAH CHEN",
            bestLap: 81_100,
            lastLap: 80_445,
            currentLap: 5,
            position: 3,
            gap: 2668
        ),
        makeRig(
            id: "rig-06",
            label: "RIG 6",
            status: .offline,
            driverName: nil,
            bestLap: nil,
            lastLap: nil,
            currentLap: nil,
            position: nil,
            gap: nil
        ),
        makeRig(
            id: "rig-07",
            label: "RIG 7",
            status: .available,
            driverName: nil,
            bestLap: nil,
            lastLap: nil,
            currentLap: nil,
            position: nil,
            gap: nil
        ),
        makeRig(
            id: "rig-08",
            label: "RIG 8",
            status: .occupied,
            driverName: "JAMES WALKER",
            bestLap: 82_560,
            lastLap: 83_100,
            currentLap: 3,
            position: 4,
            gap: 4128
        ),
        makeRig(
            id: "rig-09",
            label: "RIG 9",
            status: .available,
            driverName: nil,
            bestLap: nil,
            lastLap: nil,
            currentLap: nil,
            position: nil,
            gap: nil
        ),
        makeRig(
            id: "rig-10",
            label: "RIG 10",
            status: .available,
            driverName: nil,
            bestLap: nil,
            lastLap: nil,
            currentLap: nil,
            position: nil,
            gap: nil
        ),
    ]

    static let liveState = LiveState(
        ts: Int(Date().timeIntervalSince1970 * 1000),
        track: LiveState.Track(id: "brands-hatch", name: "Brands Hatch Indy", weather: "Clear"),
        session: LiveState.SessionInfo(phase: "race", timeLeftS: 847),
        rigs: rigs,
        competition: Competition(
            id: "comp-01",
            name: "Friday Night Fastest Lap",
            type: .fastestLap,
            status: .active,
            trackId: "brands-hatch",
            trackName: "Brands Hatch Indy",
            vehicleClass: "gt3",
            vehicleLocked: nil,
            rules: nil,
            startsAt: nil,
            endsAt: nil,
            maxParticipants: nil,
            prizeDescription: "£50 voucher",
            createdAt: 1_700_000_000
        ),
        broadcast: LiveState.BroadcastInfo(mode: .auto, focus: nil, scene: nil),
        server: LiveState.ServerInfo(status: .running)
    )

    // MARK: - Private factory

    private static func makeRig(
        id: String,
        label: String,
        status: Rig.RigStatus,
        driverName: String?,
        bestLap: Int?,
        lastLap: Int?,
        currentLap: Int?,
        position: Int?,
        gap: Int?
    ) -> LiveRig {
        LiveRig(
            id: id,
            label: label,
            location: "Bay \(id.suffix(2))",
            status: status,
            hardwareProfile: nil,
            ipAddress: nil,
            qrCodeId: "\(id)-qr",
            currentSessionId: status == .occupied ? "session-\(id)" : nil,
            createdAt: 1_700_000_000,
            updatedAt: Int(Date().timeIntervalSince1970),
            driverName: driverName,
            bestLapMs: bestLap,
            lastLapMs: lastLap,
            currentLap: currentLap,
            position: position,
            gapToLeaderMs: gap,
            pitStatus: status == .occupied ? .onTrack : nil
        )
    }
}
