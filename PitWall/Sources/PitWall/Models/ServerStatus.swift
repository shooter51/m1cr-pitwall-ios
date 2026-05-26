import Foundation

struct ServerStatus: Codable, Sendable, Equatable {
    let status: EC2Status
    let ip: String?

    enum EC2Status: String, Codable, Sendable {
        case running
        case stopped
        case starting
        case stopping

        var isTransitioning: Bool {
            self == .starting || self == .stopping
        }

        var displayName: String {
            rawValue.capitalized
        }
    }
}
