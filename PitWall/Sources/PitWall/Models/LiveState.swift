import Foundation

struct LiveState: Codable, Sendable, Equatable {
    let ts: Int
    let track: Track
    let session: SessionInfo
    let rigs: [LiveRig]
    let competition: Competition?
    let broadcast: BroadcastInfo
    let server: ServerInfo

    struct Track: Codable, Sendable, Equatable {
        let id: String
        let name: String
        let weather: String
    }

    struct SessionInfo: Codable, Sendable, Equatable {
        let phase: String
        let timeLeftS: Int
    }

    struct BroadcastInfo: Codable, Sendable, Equatable {
        let mode: BroadcastMode
        let focus: Int?
        let scene: String?

        enum BroadcastMode: String, Codable, Sendable {
            case auto
            case manual
            case off
        }
    }

    struct ServerInfo: Codable, Sendable, Equatable {
        let status: ServerStatus.EC2Status
    }
}

// MARK: - AI types

struct AIMessage: Codable, Sendable {
    let role: Role
    let content: String

    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }
}

struct AIChunk: Sendable {
    let text: String?
    let toolName: String?
    let toolStatus: String?
    let done: Bool
}

struct AuthToken: Codable, Sendable {
    let token: String
    let expiresAt: Int
}
