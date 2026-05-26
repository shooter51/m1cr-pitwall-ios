import SwiftUI

// MARK: - Font helpers
// Custom fonts (Anton, JetBrains Mono, Inter) are not yet bundled.
// These helpers use system fonts with matching design characteristics.
// To use the real fonts: add the .ttf files to Resources/, register them in
// Info.plist under UIAppFonts, then swap back to .custom() calls below.

extension Font {
    // MARK: Anton — display headings, rig labels, position numbers
    // Anton-Regular → bold system font with default design
    static func anton(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // MARK: JetBrains Mono — lap times, countdowns, timing table
    // JetBrainsMono → monospaced system font
    static func jetbrainsMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Inter — body text, labels, form fields
    // Inter is visually close to SF Pro (the system default)
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
