import Foundation

struct Competition: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let type: CompetitionType
    let status: CompetitionStatus
    let trackId: String
    let trackName: String
    let vehicleClass: String
    let vehicleLocked: String?
    let rules: AnyJSON?
    let startsAt: String?
    let endsAt: String?
    let maxParticipants: Int?
    let prizeDescription: String?
    let createdAt: String

    enum CompetitionType: String, Codable, Sendable {
        case fastestLap = "fastest_lap"
        case race
        case endurance
        case timeAttack = "time_attack"
    }

    enum CompetitionStatus: String, Codable, Sendable {
        case scheduled
        case active
        case completed
        case cancelled
    }
}

struct CreateCompetitionParams: Sendable {
    let name: String
    let type: Competition.CompetitionType
    let trackId: String
    let vehicleClass: String
    let vehicleLocked: String?
    let maxParticipants: Int?
    let prizeDescription: String?
    let startsAt: Int?
    let endsAt: Int?

    init(
        name: String,
        type: Competition.CompetitionType,
        trackId: String,
        vehicleClass: String,
        vehicleLocked: String? = nil,
        maxParticipants: Int? = nil,
        prizeDescription: String? = nil,
        startsAt: Int? = nil,
        endsAt: Int? = nil
    ) {
        self.name = name
        self.type = type
        self.trackId = trackId
        self.vehicleClass = vehicleClass
        self.vehicleLocked = vehicleLocked
        self.maxParticipants = maxParticipants
        self.prizeDescription = prizeDescription
        self.startsAt = startsAt
        self.endsAt = endsAt
    }

    var body: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "type": type.rawValue,
            "track_id": trackId,
            "vehicle_class": vehicleClass,
        ]
        if let vehicleLocked { dict["vehicle_locked"] = vehicleLocked }
        if let maxParticipants { dict["max_participants"] = maxParticipants }
        if let prizeDescription { dict["prize_description"] = prizeDescription }
        if let startsAt { dict["starts_at"] = startsAt }
        if let endsAt { dict["ends_at"] = endsAt }
        return dict
    }
}
