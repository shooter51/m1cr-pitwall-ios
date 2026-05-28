import SwiftUI

struct ChipView: View {
    let status: Rig.RigStatus

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
    }

    private var label: String {
        switch status {
        case .available: return "AVAILABLE"
        case .occupied: return "ACTIVE"
        case .maintenance: return "MAINTENANCE"
        case .offline: return "OFFLINE"
        }
    }

    private var foreground: Color {
        switch status {
        case .available: return PW.ok
        case .occupied: return PW.guards
        case .maintenance: return PW.warn
        case .offline: return PW.silverDim
        }
    }

    private var background: Color {
        foreground.opacity(0.15)
    }
}
