import Foundation

#if canImport(UIKit)
import UIKit

// MARK: - HapticsManager

@MainActor
final class HapticsManager {
    static let shared = HapticsManager()

    private init() {}

    // MARK: - Public API

    /// Heavy impact — session starting or checkered flag
    func sessionStart() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Medium impact — session ending
    func sessionEnd() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Light double tap — position change
    func positionChange() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred()
        }
    }

    /// Error style — flag change (yellow/red)
    func flagChange() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Success style — new personal best
    func newPersonalBest() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Error style — server status change (e.g. goes offline)
    func serverStatusChange(isNegative: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(isNegative ? .error : .success)
    }
}

#else

// MARK: - Stub for macOS / command-line builds

@MainActor
final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    func sessionStart() {}
    func sessionEnd() {}
    func positionChange() {}
    func flagChange() {}
    func newPersonalBest() {}
    func serverStatusChange(isNegative: Bool) {}
}

#endif
