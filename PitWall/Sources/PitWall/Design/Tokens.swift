// ============================================================
// PitWall — SwiftUI design tokens
// M1 Circuit F1 Grid visual language
// ============================================================

import SwiftUI

// MARK: - PW namespace

public enum PW {

    // MARK: Colors

    // Hex helper
    static func hex(_ rgb: UInt32, opacity: Double = 1) -> Color {
        Color(
            .sRGB,
            red:     Double((rgb >> 16) & 0xFF) / 255,
            green:   Double((rgb >>  8) & 0xFF) / 255,
            blue:    Double( rgb        & 0xFF) / 255,
            opacity: opacity
        )
    }

    // Surface
    public static let carbon   = hex(0x0A0A0B)
    public static let carbon2  = hex(0x131316)
    public static let panel    = hex(0x1A1A1D)
    public static let panel2   = hex(0x232327)
    public static let panel3   = hex(0x2A2A2F)

    // Text
    public static let silver     = hex(0xF5F5F7)
    public static let silver2    = hex(0xE5E5E8)
    public static let silverMid  = hex(0x9CA3AF)
    public static let silverDim  = hex(0x6B7280)
    public static let silverInk  = hex(0x3F4452)

    // Brand / state
    public static let guards       = hex(0xD40000)  // primary red
    public static let guardsDeep   = hex(0xA60000)  // pressed
    public static let guardsBright = hex(0xFF1F1F)  // hot / PB
    public static let ok           = hex(0x00C26F)
    public static let warn         = hex(0xFFB300)
    public static let info         = hex(0x00B8D4)

    // Lines
    public static let line       = Color.white.opacity(0.08)
    public static let lineStrong = Color.white.opacity(0.16)
    public static let lineSoft   = Color.white.opacity(0.04)

    // Status chip backgrounds
    public static let chipOccupied    = guardsBright.opacity(0.14)
    public static let chipAvailable   = ok.opacity(0.16)
    public static let chipMaintenance = warn.opacity(0.16)
    public static let chipOffline     = silverDim.opacity(0.20)

    // MARK: Spacing

    public static let sidebarWidth: CGFloat = 240
    public static let sidebarRail:  CGFloat = 56
    public static let topbarHeight: CGFloat = 60
    public static let kpiHeight:    CGFloat = 56
    public static let rowHeight:    CGFloat = 36
    public static let rowCompact:   CGFloat = 32
    public static let cardPadding:  CGFloat = 14
    public static let gap:          CGFloat = 8
    public static let gap2:         CGFloat = 10
    public static let sectionSpacing: CGFloat = 24
    public static let gridGap: CGFloat = 8

    // MARK: Fonts

    public enum FontFamily {
        public static let display = "Anton"
        public static let body    = "Inter"
        public static let mono    = "JetBrainsMono-Bold"
    }

    public enum FontStyle {
        // Display — Anton italic. Falls back to system heavy italic if not bundled.
        public static func hero(_ size: CGFloat = 124) -> Font {
            .system(size: size, weight: .black, design: .default).italic()
        }
        public static func h1(_ size: CGFloat = 56) -> Font {
            .system(size: size, weight: .black, design: .default).italic()
        }
        public static func title(_ size: CGFloat = 30) -> Font {
            .system(size: size, weight: .black, design: .default).italic()
        }
        public static func card(_ size: CGFloat = 26) -> Font {
            .system(size: size, weight: .black, design: .default).italic()
        }
        // Body — Inter. System default is close enough.
        public static func body(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        // Mono — JetBrains Mono. System monospaced is the fallback.
        public static func mono(_ size: CGFloat = 10, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        public static func telemetry(_ size: CGFloat = 22) -> Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }
    }

    // MARK: Motion
    public static let durFast   = 0.08
    public static let dur       = 0.12
    public static let durSlow   = 0.20
    public static let pulseDur  = 1.60
}

// MARK: - Color hex initialiser (keep for backward compat)

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(hex string: String) {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(hex: UInt32(int))
    }
}

// MARK: - View modifiers

extension View {

    /// Mono uppercase label
    func pwMonoLabel(_ size: CGFloat = 10,
                     color: Color = PW.silverMid,
                     tracking: CGFloat = 1.6) -> some View {
        self
            .font(PW.FontStyle.mono(size, weight: .semibold))
            .foregroundColor(color)
            .tracking(tracking)
            .textCase(.uppercase)
    }

    /// `// 01 — SECTION` eyebrow
    func pwEyebrow(color: Color = PW.guardsBright) -> some View {
        self
            .font(PW.FontStyle.mono(9, weight: .bold))
            .foregroundColor(color)
            .tracking(2.2)
            .textCase(.uppercase)
    }

    /// Anton italic display headline
    func pwDisplay(_ size: CGFloat) -> some View {
        self
            .font(PW.FontStyle.title(size))
            .foregroundColor(PW.silver)
            .tracking(size > 60 ? -size * 0.03 : -size * 0.02)
            .textCase(.uppercase)
    }
}

// MARK: - PrimaryButtonStyle (parallelogram cut)

public struct PrimaryButtonStyle: ButtonStyle {
    public enum Variant { case primary, secondary, danger }
    public var variant: Variant = .primary
    public var compact: Bool    = false

    public init(_ variant: Variant = .primary, compact: Bool = false) {
        self.variant = variant
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PW.FontStyle.mono(compact ? 10 : 11, weight: .bold))
            .tracking(1.6)
            .textCase(.uppercase)
            .padding(.horizontal, compact ? 22 : 30)
            .padding(.vertical,   compact ? 8  : 12)
            .foregroundColor(foreground)
            .background(background)
            .overlay(
                Rectangle().stroke(border, lineWidth: 1)
            )
            .clipShape(CutShape())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    private var foreground: Color {
        switch variant {
        case .primary:   return .white
        case .secondary: return PW.silver
        case .danger:    return PW.guardsBright
        }
    }
    private var background: Color {
        switch variant {
        case .primary: return PW.guards
        default:       return .clear
        }
    }
    private var border: Color {
        switch variant {
        case .primary:   return PW.guards
        case .secondary: return PW.lineStrong
        case .danger:    return PW.guardsBright
        }
    }
}

/// The 7%/93% parallelogram clip-path
public struct CutShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let dx = rect.width * 0.07
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + dx,    y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,      y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - dx, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX,      y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - StatusChip

public struct StatusChip: View {
    public enum Status: String {
        case occupied, available, maintenance, offline, live, full, ended
    }
    let status: Status
    var compact: Bool = false

    public init(_ status: Status, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }

    public var body: some View {
        Text(status.rawValue.uppercased())
            .font(PW.FontStyle.mono(compact ? 9 : 10, weight: .bold))
            .tracking(1.8)
            .foregroundColor(foreground)
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical,   compact ? 3 : 4)
            .background(background)
    }

    private var foreground: Color {
        switch status {
        case .occupied, .live:  return PW.guardsBright
        case .available:        return PW.ok
        case .maintenance, .full: return PW.warn
        case .offline, .ended:  return PW.silverDim
        }
    }
    private var background: Color {
        switch status {
        case .occupied, .live:    return PW.chipOccupied
        case .available:          return PW.chipAvailable
        case .maintenance, .full: return PW.chipMaintenance
        case .offline, .ended:    return PW.chipOffline
        }
    }
}

// MARK: - Live dot (pulsing)

public struct LiveDot: View {
    @State private var on = true
    var color: Color = PW.guardsBright
    var size: CGFloat = 7

    public init(color: Color = PW.guardsBright, size: CGFloat = 7) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(on ? 1 : 0.4)
            .onAppear {
                withAnimation(.easeInOut(duration: PW.pulseDur).repeatForever(autoreverses: true)) {
                    on.toggle()
                }
            }
    }
}

// MARK: - Diagonal stripes (decorative corner)

public struct CornerStripes: View {
    var size: CGFloat = 90
    public init(size: CGFloat = 90) { self.size = size }
    public var body: some View {
        Canvas { ctx, sz in
            let step: CGFloat = 12
            var x: CGFloat = -sz.height
            while x < sz.width + sz.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + 4, y: 0))
                path.addLine(to: CGPoint(x: x + 4 + sz.height, y: sz.height))
                path.addLine(to: CGPoint(x: x + sz.height, y: sz.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(PW.guards.opacity(0.6)))
                x += step
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}
