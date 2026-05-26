import Testing
import Foundation
@testable import PitWall

@Suite("AnyJSON")
struct AnyJSONTests {

    @Test("String encode/decode round-trip")
    func stringRoundTrip() throws {
        let value = AnyJSON.string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == .string("hello"))
    }

    @Test("Number encode/decode round-trip")
    func numberRoundTrip() throws {
        let value = AnyJSON.number(42.5)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == .number(42.5))
    }

    @Test("Bool true encode/decode round-trip")
    func boolTrueRoundTrip() throws {
        let value = AnyJSON.bool(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == .bool(true))
    }

    @Test("Bool false encode/decode round-trip")
    func boolFalseRoundTrip() throws {
        let value = AnyJSON.bool(false)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == .bool(false))
    }

    @Test("Null encode/decode round-trip")
    func nullRoundTrip() throws {
        let value = AnyJSON.null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == .null)
    }

    @Test("Array encode/decode round-trip")
    func arrayRoundTrip() throws {
        let value = AnyJSON.array([.string("a"), .number(1), .bool(true), .null])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == value)
    }

    @Test("Object encode/decode round-trip")
    func objectRoundTrip() throws {
        let value = AnyJSON.object([
            "name": .string("test"),
            "count": .number(3),
            "active": .bool(false),
            "data": .null,
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == value)
    }

    @Test("Nested object/array round-trip")
    func nestedRoundTrip() throws {
        let value = AnyJSON.object([
            "items": .array([
                .object(["id": .number(1), "label": .string("first")]),
                .object(["id": .number(2), "label": .string("second")]),
            ]),
            "meta": .null,
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
        #expect(decoded == value)
    }

    @Test("Decode from raw JSON string")
    func decodeFromRawJSON() throws {
        let json = """
        {"key": "value", "num": 99, "flag": true, "nothing": null}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: AnyJSON].self, from: json)

        #expect(decoded["key"] == .string("value"))
        #expect(decoded["num"] == .number(99))
        #expect(decoded["flag"] == .bool(true))
        #expect(decoded["nothing"] == .null)
    }

    @Test("Equatable distinguishes types")
    func equatableDistinguishesTypes() {
        #expect(AnyJSON.string("1") != AnyJSON.number(1))
        #expect(AnyJSON.bool(true) != AnyJSON.number(1))
        #expect(AnyJSON.null != AnyJSON.bool(false))
    }
}
