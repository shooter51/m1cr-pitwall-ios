import SwiftUI

// MARK: - PitWall design tokens — mirrors the web T object 1:1

enum PW {
    // MARK: Colors

    static let carbon       = Color(hex: 0x0A0A0B)
    static let carbon2      = Color(hex: 0x131316)
    static let panel        = Color(hex: 0x1A1A1D)
    static let panel2       = Color(hex: 0x232327)
    static let panel3       = Color(hex: 0x2A2A2F)
    static let silver       = Color(hex: 0xF5F5F7)
    static let silver2      = Color(hex: 0xE5E5E8)
    static let silverMid    = Color(hex: 0x9CA3AF)
    static let silverDim    = Color(hex: 0x6B7280)
    static let guards       = Color(hex: 0xD40000)
    static let guardsDeep   = Color(hex: 0xA60000)
    static let guardsBright = Color(hex: 0xFF1F1F)
    static let line         = Color.white.opacity(0.08)
    static let lineStrong   = Color.white.opacity(0.16)
    static let lineSoft     = Color.white.opacity(0.04)
    static let ok           = Color(hex: 0x00C26F)
    static let warn         = Color(hex: 0xFFB300)
    static let info         = Color(hex: 0x00B8D4)

    // MARK: Spacing

    static let gridGap: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let sidebarWidth: CGFloat = 280
}

// MARK: - Parallelogram shape (primary CTA)

struct Parallelogram: Shape {
    var skew: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: skew, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Primary button style (parallelogram, guards red)

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(PW.silver)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Parallelogram()
                    .fill(configuration.isPressed ? PW.guardsDeep : PW.guards)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Color hex initialiser

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    // Also accept a hex string e.g. "#0A0A0B"
    init(hex string: String) {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(hex: UInt32(int))
    }
}
