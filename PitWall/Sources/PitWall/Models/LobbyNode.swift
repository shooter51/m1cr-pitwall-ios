import Foundation

/// Mirror of the `NodePayload` returned by Lobby (`/lobby/nodes`).
/// See `m1cr-pitwall/docs/adr/0004-lobby-and-race-postings.md` §2.2.
struct LobbyNode: Codable, Equatable, Identifiable, Hashable, Sendable {
    let id: String
    let parentId: String?
    let name: String
    let slug: String
    let kind: Kind
    let metadata: [String: AnyJSON]
    let mc: MCInfo
    let `operator`: OperatorInfo?
    let live: LiveCounts

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        name = try c.decode(String.self, forKey: .name)
        slug = try c.decode(String.self, forKey: .slug)
        kind = try c.decode(Kind.self, forKey: .kind)
        metadata = try c.decodeIfPresent([String: AnyJSON].self, forKey: .metadata) ?? [:]
        mc = try c.decodeIfPresent(MCInfo.self, forKey: .mc) ?? MCInfo(url: nil, isRunning: false, startedAt: nil)
        `operator` = try c.decodeIfPresent(OperatorInfo.self, forKey: .operator)
        live = try c.decodeIfPresent(LiveCounts.self, forKey: .live) ?? LiveCounts(activeSessions: 0, activeRaces: 0, activePostings: 0)
    }

    enum Kind: String, Codable, Sendable {
        case location, org
    }

    struct MCInfo: Codable, Equatable, Hashable, Sendable {
        let url: String?
        let isRunning: Bool
        let startedAt: String?
    }

    struct OperatorInfo: Codable, Equatable, Hashable, Sendable {
        let deviceId: String
        let display: String?
        let attachedAt: String
    }

    struct LiveCounts: Codable, Equatable, Hashable, Sendable {
        let activeSessions: Int
        let activeRaces: Int
        let activePostings: Int
    }
}

/// A tiny `Codable` wrapper so `metadata` (free-form JSON) round-trips through
/// `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` without losing
/// data we can't statically type.
enum AnyJSON: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([AnyJSON])
    case object([String: AnyJSON])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)   { self = .bool(v);   return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyJSON].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyJSON].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "Unsupported JSON value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .null:          try c.encodeNil()
        case .array(let v):  try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

struct LobbyNodeList: Codable {
    let nodes: [LobbyNode]
}

struct CreateNodeBody: Encodable {
    let name: String
    let slug: String
    let kind: LobbyNode.Kind
    let parentId: String?
}

struct AttachBody: Encodable {
    let deviceId: String
    let display: String?
}
