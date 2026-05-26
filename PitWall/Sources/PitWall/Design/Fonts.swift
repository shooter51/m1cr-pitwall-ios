import SwiftUI

// MARK: - Font helpers
// Custom fonts (Anton, JetBrains Mono, Inter) must be bundled in Resources/
// and registered in Info.plist under UIAppFonts.
// These helpers fall back to system fonts until the custom fonts are added.

extension Font {
    // MARK: Anton — display headings, rig labels, position numbers
    static func anton(size: CGFloat) -> Font {
        .custom("Anton-Regular", size: size, relativeTo: .headline)
    }

    // MARK: JetBrains Mono — lap times, countdowns, timing table
    static func jetbrainsMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = weight == .bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular"
        return .custom(name, size: size, relativeTo: .body)
    }

    // MARK: Inter — body text, labels, form fields
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold: name = "Inter-SemiBold"
        case .bold:     name = "Inter-Bold"
        case .medium:   name = "Inter-Medium"
        default:        name = "Inter-Regular"
        }
        return .custom(name, size: size, relativeTo: .body)
    }
}
