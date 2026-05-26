import Foundation

/// Mirror of `race_postings` rows returned by an Org MC at `/api/race-wall`.
/// See `m1cr-pitwall/docs/adr/0004-lobby-and-race-postings.md` §3.2.
struct RacePosting: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let sourceOrgId: String
    let targetOrgId: String
    let competitionId: String?
    let trackName: String
    let trackId: String
    let vehicleClass: String
    let vehicleName: String?
    let slotTotal: Int
    let slotOpen: Int
    let thumbnailUrl: String?
    let status: Status
    let startedAt: String
    let endsAt: String?

    /// Joined-in on the race-wall response (`/api/race-wall`).
    let sourceName: String?
    let sourceSlug: String?

    enum Status: String, Codable {
        case live, full, ended, cancelled
    }
}

struct RacePostingList: Codable {
    let postings: [RacePosting]
}

struct PostingDraft: Encodable {
    let trackId: String
    let trackName: String
    let vehicleClass: String
    let vehicleName: String?
    let slotTotal: Int
    let slotOpen: Int
    let thumbnailUrl: String?
    let endsAt: String?
}
