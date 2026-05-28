import Foundation

/// Leaderboard entry returned by GET /api/pitwall/laps (grouped by driver).
struct LeaderboardEntry: Codable, Sendable, Equatable {
    let driverName: String
    let bestLapMs: Int
    let trackName: String
    let vehicleClass: String
    let lastAt: String?
}

/// Response wrappers for POST endpoints that return partial data.
struct SessionCreateResponse: Codable, Sendable {
    let sessionId: String
    let rigId: String
    let durationMinutes: Int
}

struct CompetitionCreateResponse: Codable, Sendable {
    let id: String
    let startsAt: String
    let endsAt: String?
}

struct LapTime: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let sessionId: String
    let rigId: String
    let driverName: String
    let trackId: String
    let trackName: String
    let vehicleClass: String
    let vehicleName: String
    let lapNumber: Int
    let lapTimeMs: Int
    let sector1Ms: Int?
    let sector2Ms: Int?
    let sector3Ms: Int?
    let isValid: Int      // 0 | 1
    let isPersonalBest: Int  // 0 | 1
    let weatherConditions: String?
    let recordedAt: Int

    var isValidBool: Bool { isValid == 1 }
    var isPersonalBestBool: Bool { isPersonalBest == 1 }
}

struct LapFilter: Sendable {
    let track: String?
    let vehicleClass: String?
    let driverName: String?
    let period: String?
    let limit: Int?

    init(
        track: String? = nil,
        vehicleClass: String? = nil,
        driverName: String? = nil,
        period: String? = nil,
        limit: Int? = nil
    ) {
        self.track = track
        self.vehicleClass = vehicleClass
        self.driverName = driverName
        self.period = period
        self.limit = limit
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let track { items.append(URLQueryItem(name: "track", value: track)) }
        if let vehicleClass { items.append(URLQueryItem(name: "vehicle_class", value: vehicleClass)) }
        if let driverName { items.append(URLQueryItem(name: "driver_name", value: driverName)) }
        if let period { items.append(URLQueryItem(name: "period", value: period)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return items
    }
}
