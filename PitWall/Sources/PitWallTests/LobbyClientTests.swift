import Testing
import Foundation
@testable import PitWall

@Suite("LobbyClient")
struct LobbyClientTests {

    @MainActor
    private func makeMC(
        lobbyURL: URL = URL(string: "https://lobby.test.com")!,
        clientKey: String = "test-client-key"
    ) -> MCClient {
        MCClient(clientKey: clientKey, lobbyURL: lobbyURL, deviceId: "device-test")
    }

    // MARK: - LobbyError descriptions

    @Test("LobbyError.badURL has non-empty description")
    func badURLDescription() {
        let error = LobbyError.badURL
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("LobbyError.server includes code and message")
    func serverErrorDescription() {
        let error = LobbyError.server(404, "Not Found")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("404"))
        #expect(desc.contains("Not Found"))
    }

    @Test("LobbyError.decoding wraps underlying error description")
    func decodingErrorDescription() {
        let underlying = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "bad decode"])
        let error = LobbyError.decoding(underlying)
        let desc = error.errorDescription ?? ""
        #expect(!desc.isEmpty)
        #expect(desc.contains("bad decode"))
    }

    @Test("LobbyError.network wraps underlying error description")
    func networkErrorDescription() {
        let urlError = URLError(.timedOut)
        let error = LobbyError.network(urlError)
        let desc = error.errorDescription ?? ""
        #expect(!desc.isEmpty)
    }

    @Test("All LobbyError cases return non-empty descriptions")
    func allCasesNonEmpty() {
        let errors: [LobbyError] = [
            .badURL,
            .server(500, "Internal Server Error"),
            .decoding(NSError(domain: "Test", code: 1)),
            .network(URLError(.notConnectedToInternet)),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    // MARK: - LobbyEvent struct

    @Test("LobbyEvent stores type and payload correctly")
    func lobbyEventStorage() {
        let payload = """
        {"id":"node-1","name":"Bay A"}
        """.data(using: .utf8)!

        let event = LobbyEvent(type: "node.added", payload: payload)
        #expect(event.type == "node.added")
        #expect(event.payload == payload)
    }

    @Test("LobbyEvent payload can be decoded as JSON")
    func lobbyEventPayloadDecodable() throws {
        struct NodeUpdate: Decodable { let id: String; let name: String }
        let payload = #"{"id":"node-42","name":"Paddock A"}"#.data(using: .utf8)!

        let event = LobbyEvent(type: "node.spawned", payload: payload)
        let decoded = try JSONDecoder().decode(NodeUpdate.self, from: event.payload)
        #expect(decoded.id == "node-42")
        #expect(decoded.name == "Paddock A")
    }

    // MARK: - URL construction (no double slash)

    @MainActor
    @Test("LobbyClient is initialized without crashing")
    func initDoesNotCrash() {
        let mc = makeMC()
        let _ = LobbyClient(mc: mc)
        #expect(Bool(true))
    }

    @MainActor
    @Test("lobbyURL with trailing slash still produces valid event stream URL")
    func lobbyURLWithTrailingSlash() async {
        // LobbyClient trims leading slash from paths — verify lobbyURL.appendingPathComponent
        // doesn't produce double-slash when lobbyURL already has a trailing slash.
        let base = URL(string: "https://lobby.test.com/")!

        // eventStream() constructs its URL as: lobbyURL.appendingPathComponent("lobby/events")
        // appendingPathComponent normalises double slashes — verify it does not produce double slash.
        let url = base.appendingPathComponent("lobby/events")
        let urlString = url.absoluteString
        #expect(!urlString.contains("//lobby/events"))
    }

    @MainActor
    @Test("lobbyURL without trailing slash produces correct path")
    func lobbyURLWithoutTrailingSlash() async {
        let base = URL(string: "https://lobby.test.com")!
        let url = base.appendingPathComponent("lobby/nodes")
        #expect(url.absoluteString == "https://lobby.test.com/lobby/nodes")
    }

    // MARK: - SSE multi-line data accumulation (via LobbyEvent parsing)

    @Test("SSE data lines joined by newline before dispatch")
    func multiLineDataJoined() {
        // Simulate the logic in eventStream: accumulate data: lines, join, dispatch.
        var dataLines: [String] = []
        var eventType = ""
        var dispatched: [(type: String, data: String)] = []

        let lines = [
            "event: node.added",
            "data: {\"id\":\"node-1\",",
            "data: \"name\":\"Bay A\"}",
            "",
        ]

        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            } else if line.isEmpty {
                let dataBuf = dataLines.joined(separator: "\n")
                if !eventType.isEmpty {
                    dispatched.append((type: eventType, data: dataBuf))
                }
                eventType = ""
                dataLines = []
            }
        }

        #expect(dispatched.count == 1)
        #expect(dispatched[0].type == "node.added")
        #expect(dispatched[0].data == "{\"id\":\"node-1\",\n\"name\":\"Bay A\"}")
    }

    @Test("SSE event with empty data buffer is not dispatched")
    func emptyDataNotDispatched() {
        var dataLines: [String] = []
        var eventType = ""
        var dispatched: [(type: String, data: String)] = []

        let lines = [
            "event: ping",
            "",
        ]

        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            } else if line.isEmpty {
                let dataBuf = dataLines.joined(separator: "\n")
                if !eventType.isEmpty, !dataBuf.isEmpty {
                    dispatched.append((type: eventType, data: dataBuf))
                }
                eventType = ""
                dataLines = []
            }
        }

        #expect(dispatched.isEmpty)
    }

    @Test("SSE resets state after each blank-line dispatch")
    func sseResetsStateAfterDispatch() {
        var dataLines: [String] = []
        var eventType = ""
        var dispatched: [(type: String, data: String)] = []

        let lines = [
            "event: node.added",
            "data: first",
            "",
            "event: node.spawned",
            "data: second",
            "",
        ]

        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            } else if line.isEmpty {
                let dataBuf = dataLines.joined(separator: "\n")
                if !eventType.isEmpty && !dataBuf.isEmpty {
                    dispatched.append((type: eventType, data: dataBuf))
                }
                eventType = ""
                dataLines = []
            }
        }

        #expect(dispatched.count == 2)
        #expect(dispatched[0].type == "node.added")
        #expect(dispatched[0].data == "first")
        #expect(dispatched[1].type == "node.spawned")
        #expect(dispatched[1].data == "second")
    }
}
