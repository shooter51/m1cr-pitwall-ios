import SwiftUI

struct StatusDot: View {
    let status: ServerStatus.EC2Status

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch status {
        case .running: return PW.ok
        case .stopped: return PW.silverDim
        case .starting: return PW.warn
        case .stopping: return PW.warn
        }
    }
}
