import Foundation

/// Shared lap time formatting utilities used across all timing views.
enum LapTimeFormatter {
    /// Format a lap time in milliseconds as "M:SS.mmm" (e.g. "1:23.456").
    /// Returns "--:--.---" when ms is nil.
    static func format(_ ms: Int?) -> String {
        guard let ms else { return "--:--.---" }
        let m = ms / 60_000
        let s = Double(ms % 60_000) / 1000.0
        return String(format: "%d:%06.3f", m, s)
    }

    /// Format a non-optional lap time in milliseconds.
    static func format(_ ms: Int) -> String {
        let m = ms / 60_000
        let s = Double(ms % 60_000) / 1000.0
        return String(format: "%d:%06.3f", m, s)
    }
}
