import Foundation

struct Session: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let rigId: String
    let bookingId: String?
    let driverName: String
    let driverEmail: String?
    let driverPhone: String?
    let checkInMethod: CheckInMethod
    let status: SessionStatus
    let startedAt: String
    let endedAt: String?
    let durationMinutes: Int?
    let steamParticipantId: Int?
    let experienceLevel: ExperienceLevel?
    let metadata: AnyJSON?

    enum CheckInMethod: String, Codable, Sendable {
        case qr
        case `operator`
    }

    enum SessionStatus: String, Codable, Sendable {
        case active
        case completed
        case expired
        case cancelled
    }

    enum ExperienceLevel: String, Codable, Sendable {
        case beginner
        case intermediate
        case expert
    }
}

struct StartSessionParams: Sendable {
    let rigId: String
    let driverName: String
    let durationMinutes: Int
    let driverEmail: String?
    let experienceLevel: Session.ExperienceLevel?

    init(
        rigId: String,
        driverName: String,
        durationMinutes: Int,
        driverEmail: String? = nil,
        experienceLevel: Session.ExperienceLevel? = nil
    ) {
        self.rigId = rigId
        self.driverName = driverName
        self.durationMinutes = durationMinutes
        self.driverEmail = driverEmail
        self.experienceLevel = experienceLevel
    }

    var body: [String: Any] {
        var dict: [String: Any] = [
            "rig_id": rigId,
            "driver_name": driverName,
            "duration_minutes": durationMinutes,
            "check_in_method": "operator",
        ]
        if let email = driverEmail { dict["driver_email"] = email }
        if let level = experienceLevel { dict["experience_level"] = level.rawValue }
        return dict
    }
}

struct SessionFilter: Sendable {
    let rigId: String?
    let status: Session.SessionStatus?
    let limit: Int?

    init(rigId: String? = nil, status: Session.SessionStatus? = nil, limit: Int? = nil) {
        self.rigId = rigId
        self.status = status
        self.limit = limit
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let rigId { items.append(URLQueryItem(name: "rig_id", value: rigId)) }
        if let status { items.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return items
    }
}
