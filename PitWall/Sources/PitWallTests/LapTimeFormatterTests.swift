import Testing
import Foundation
@testable import PitWall

@Suite("LapTimeFormatter")
struct LapTimeFormatterTests {

    // MARK: - Non-optional overload

    @Test("Zero milliseconds formats as 0:00.000")
    func zeroMs() {
        #expect(LapTimeFormatter.format(0) == "0:00.000")
    }

    @Test("Exactly one minute formats correctly")
    func exactlyOneMinute() {
        // 60000 ms = 1 min 0 sec
        #expect(LapTimeFormatter.format(60_000) == "1:00.000")
    }

    @Test("Sub-minute lap time formats correctly")
    func subMinuteLap() {
        // 78432 ms = 1:18.432
        #expect(LapTimeFormatter.format(78_432) == "1:18.432")
    }

    @Test("Lap time with sub-second portion formats correctly")
    func subSecondPortion() {
        // 1500 ms = 0:01.500
        #expect(LapTimeFormatter.format(1_500) == "0:01.500")
    }

    @Test("Multi-minute lap time formats correctly")
    func multiMinuteLap() {
        // 135000 ms = 2:15.000
        #expect(LapTimeFormatter.format(135_000) == "2:15.000")
    }

    @Test("Lap time milliseconds precision preserved")
    func millisecondPrecision() {
        // 60001 ms = 1:00.001
        #expect(LapTimeFormatter.format(60_001) == "1:00.001")
    }

    @Test("Very large lap time (10 minutes+) formats correctly")
    func veryLargeLap() {
        // 660000 ms = 11:00.000
        #expect(LapTimeFormatter.format(660_000) == "11:00.000")
    }

    @Test("999 ms formats with leading zero seconds")
    func subSecondLeadingZero() {
        // 999 ms = 0:00.999
        #expect(LapTimeFormatter.format(999) == "0:00.999")
    }

    // MARK: - Optional overload

    @Test("Nil ms returns placeholder string")
    func nilMs() {
        #expect(LapTimeFormatter.format(nil) == "--:--.---")
    }

    @Test("Non-nil optional formats the same as non-optional")
    func nonNilOptional() {
        let ms: Int? = 78_432
        #expect(LapTimeFormatter.format(ms) == LapTimeFormatter.format(78_432))
    }

    @Test("Optional zero formats the same as non-optional zero")
    func optionalZero() {
        let ms: Int? = 0
        #expect(LapTimeFormatter.format(ms) == "0:00.000")
    }

    @Test("Placeholder is not empty and contains separators")
    func placeholderFormat() {
        let placeholder = LapTimeFormatter.format(nil)
        #expect(!placeholder.isEmpty)
        #expect(placeholder.contains(":"))
        #expect(placeholder.contains("."))
    }
}
