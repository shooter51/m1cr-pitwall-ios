import Testing
import Foundation
@testable import PitWall

// MARK: - SSEClient tests
// Tests the SSE parsing logic by standing up a minimal local HTTP server
// that emits SSE events in the real format, then verifying the parsed output.

@Suite("SSEClient")
struct SSEClientTests {

    // MARK: - SSE parsing via local server

    @Test("SSEClient parses a snapshot event into LiveState")
    func parsesSnapshotEvent() async throws {
        let server = try LocalSSEServer()
        server.queueEvent(type: "snapshot", data: sampleLiveStateJSON())
        server.closeAfterEvents()

        let client = SSEClient()
        let stream = await client.connect(url: server.url, headers: [:])

        var received: [LiveState] = []
        for await state in stream {
            received.append(state)
        }

        #expect(received.count == 1)
        let state = try #require(received.first)
        #expect(state.track.id == "brands-hatch")
        #expect(state.session.phase == "race")
        #expect(state.rigs.count == 1)
        #expect(state.server.status == .running)

        await client.disconnect()
        server.stop()
    }

    @Test("SSEClient parses multiple snapshot events")
    func parsesMultipleEvents() async throws {
        let server = try LocalSSEServer()

        for i in 1...3 {
            server.queueEvent(type: "snapshot", data: sampleLiveStateJSON(ts: i * 1000))
        }
        server.closeAfterEvents()

        let client = SSEClient()
        let stream = await client.connect(url: server.url, headers: [:])

        var received: [LiveState] = []
        for await state in stream {
            received.append(state)
            if received.count == 3 { break }
        }

        #expect(received.count == 3)
        let timestamps = Set(received.map(\.ts))
        #expect(timestamps.count == 3)

        await client.disconnect()
        server.stop()
    }

    @Test("SSEClient skips non-snapshot events")
    func skipsHeartbeats() async throws {
        let server = try LocalSSEServer()
        server.queueEvent(type: "ping", data: "heartbeat")
        server.queueEvent(type: "snapshot", data: sampleLiveStateJSON(ts: 9999))
        server.queueEvent(type: "ping", data: "heartbeat")
        server.closeAfterEvents()

        let client = SSEClient()
        let stream = await client.connect(url: server.url, headers: [:])

        var received: [LiveState] = []
        for await state in stream {
            received.append(state)
        }

        #expect(received.count == 1)
        #expect(received.first?.ts == 9999)

        await client.disconnect()
        server.stop()
    }

    @Test("SSEClient skips malformed data lines")
    func skipsMalformedData() async throws {
        let server = try LocalSSEServer()
        server.queueEvent(type: "snapshot", data: "not-valid-json{{{")
        server.queueEvent(type: "snapshot", data: sampleLiveStateJSON(ts: 42))
        server.closeAfterEvents()

        let client = SSEClient()
        let stream = await client.connect(url: server.url, headers: [:])

        var received: [LiveState] = []
        for await state in stream {
            received.append(state)
        }

        #expect(received.count == 1)
        #expect(received.first?.ts == 42)

        await client.disconnect()
        server.stop()
    }

    @Test("SSEClient passes Authorization header to server")
    func sendsAuthHeader() async throws {
        let server = try LocalSSEServer()
        server.queueEvent(type: "snapshot", data: sampleLiveStateJSON())
        server.closeAfterEvents()

        let client = SSEClient()
        let stream = await client.connect(
            url: server.url,
            headers: ["Authorization": "Bearer test-token-abc"]
        )

        for await _ in stream { break }

        let receivedAuthHeader = server.lastAuthorizationHeader
        #expect(receivedAuthHeader == "Bearer test-token-abc")

        await client.disconnect()
        server.stop()
    }

    @Test("SSEClient disconnect stops the stream")
    func disconnectStopsStream() async throws {
        let server = try LocalSSEServer()
        server.queueEvent(type: "snapshot", data: sampleLiveStateJSON())

        let client = SSEClient()
        let stream = await client.connect(url: server.url, headers: [:])

        var count = 0
        let task = Task {
            for await _ in stream {
                count += 1
                if count >= 1 {
                    await client.disconnect()
                    break
                }
            }
        }
        await task.value

        #expect(count >= 1)
        server.stop()
    }

    // MARK: - SSEError descriptions

    @Test("SSEError errorDescription returns non-empty strings")
    func sseErrorDescriptions() {
        let errors: [SSEError] = [
            .invalidURL,
            .connectionFailed(URLError(.timedOut)),
            .streamTerminated,
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    // MARK: - Helpers

    private func sampleLiveStateJSON(ts: Int = 1700001234) -> String {
        """
        {"ts":\(ts),"track":{"id":"brands-hatch","name":"Brands Hatch Indy","weather":"Clear"},"session":{"phase":"race","time_left_s":847},"rigs":[{"id":"rig-01","label":"RIG 1","location":"Bay 01","status":"occupied","hardware_profile":null,"ip_address":null,"qr_code_id":"qr-01","current_session_id":"s-01","created_at":1700000000,"updated_at":1700001000,"driver_name":"TOM","best_lap_ms":78432,"last_lap_ms":79012,"current_lap":8,"position":1,"gap_to_leader_ms":0,"pit_status":"on_track"}],"competition":null,"broadcast":{"mode":"auto","focus":null,"scene":null},"server":{"status":"running"}}
        """
    }
}

// MARK: - Minimal local SSE test server

/// A bare-minimum HTTP/1.1 server that emits SSE events for testing.
/// Binds to a random port on localhost.
final class LocalSSEServer {
    // All mutable state is accessed only from the background accept thread
    // plus the main thread (before the thread starts). We use an NSLock
    // to protect shared state.
    private let serverSocket: Int32
    let port: Int

    private let lock = NSLock()
    private var _clientSocket: Int32 = -1
    private var _eventQueue: [(type: String, data: String)] = []
    private var _shouldClose = false
    private var _lastAuthHeader: String?

    var url: URL {
        URL(string: "http://127.0.0.1:\(port)/sse")!
    }

    var lastAuthorizationHeader: String? {
        lock.lock()
        defer { lock.unlock() }
        return _lastAuthHeader
    }

    init() throws {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw SSEError.connectionFailed(URLError(.cannotConnectToHost))
        }
        serverSocket = sock

        var one: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))

        // Bind to a random port
        port = try LocalSSEServer.doBind(socket: sock)
        listen(sock, 1)

        // Accept on background thread
        let selfRef = self
        let thread = Thread { selfRef.acceptLoop() }
        thread.start()
    }

    func queueEvent(type: String, data: String) {
        lock.lock()
        _eventQueue.append((type: type, data: data))
        lock.unlock()
    }

    func closeAfterEvents() {
        lock.lock()
        _shouldClose = true
        lock.unlock()
    }

    func stop() {
        close(serverSocket)
        lock.lock()
        let fd = _clientSocket
        lock.unlock()
        if fd >= 0 { close(fd) }
    }

    // MARK: - Private

    private static func doBind(socket sock: Int32) throws -> Int {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = CFSwapInt32HostToBig(INADDR_LOOPBACK)
        addr.sin_port = 0

        var bindResult: Int32 = -1
        withUnsafeMutableBytes(of: &addr) { buf in
            buf.baseAddress!.withMemoryRebound(to: sockaddr.self, capacity: 1) { saddr in
                bindResult = bind(sock, saddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(sock)
            throw SSEError.connectionFailed(URLError(.cannotConnectToHost))
        }

        var assignedAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutableBytes(of: &assignedAddr) { buf in
            buf.baseAddress!.withMemoryRebound(to: sockaddr.self, capacity: 1) { saddr in
                _ = getsockname(sock, saddr, &len)
            }
        }
        return Int(CFSwapInt16BigToHost(assignedAddr.sin_port))
    }

    private func acceptLoop() {
        var clientAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        var fd: Int32 = -1
        withUnsafeMutableBytes(of: &clientAddr) { buf in
            buf.baseAddress!.withMemoryRebound(to: sockaddr.self, capacity: 1) { saddr in
                fd = accept(serverSocket, saddr, &len)
            }
        }
        guard fd >= 0 else { return }

        lock.lock()
        _clientSocket = fd
        lock.unlock()

        // Read HTTP request headers
        var buf = [UInt8](repeating: 0, count: 1)
        var headerStr = ""
        while !headerStr.contains("\r\n\r\n") {
            let n = recv(fd, &buf, 1, 0)
            if n <= 0 { break }
            headerStr += String(bytes: buf, encoding: .utf8) ?? ""
        }

        // Extract Authorization header
        for line in headerStr.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("authorization:") {
                let value = String(line.dropFirst("authorization:".count)).trimmingCharacters(in: .whitespaces)
                lock.lock()
                _lastAuthHeader = value
                lock.unlock()
            }
        }

        // Send SSE response headers
        let headers = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
        let headerBytes = [UInt8](headers.utf8)
        _ = send(fd, headerBytes, headerBytes.count, 0)

        // Wait a bit then emit queued events
        Thread.sleep(forTimeInterval: 0.05)

        lock.lock()
        let events = _eventQueue
        let shouldClose = _shouldClose
        lock.unlock()

        for event in events {
            let payload = "event: \(event.type)\ndata: \(event.data)\n\n"
            let payloadBytes = [UInt8](payload.utf8)
            _ = send(fd, payloadBytes, payloadBytes.count, 0)
            Thread.sleep(forTimeInterval: 0.02)
        }

        if shouldClose {
            close(fd)
            lock.lock()
            _clientSocket = -1
            lock.unlock()
        }
    }
}
