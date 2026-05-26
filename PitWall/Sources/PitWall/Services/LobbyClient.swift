import Foundation

enum LobbyError: Error, LocalizedError {
    case badURL
    case server(Int, String)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid lobby URL."
        case .server(let code, let msg): return "Lobby \(code): \(msg)"
        case .decoding(let e): return "Decoding error: \(e.localizedDescription)"
        case .network(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

/// HTTP + SSE client for the Lobby control plane.
/// All routes are gated by `X-PitWall-Key`.
actor LobbyClient {
    private let mc: MCClient

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    init(mc: MCClient) {
        self.mc = mc
    }

    func listNodes() async throws -> [LobbyNode] {
        let req = try await buildRequest("GET", "/lobby/nodes")
        return try await execute(req, as: LobbyNodeList.self).nodes
    }

    func createNode(_ body: CreateNodeBody) async throws -> LobbyNode {
        var req = try await buildRequest("POST", "/lobby/nodes")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        struct Wrapper: Decodable { let node: LobbyNode }
        return try await execute(req, as: Wrapper.self).node
    }

    func spawn(nodeId: String) async throws {
        let req = try await buildRequest("POST", "/lobby/nodes/\(nodeId)/spawn")
        _ = try await executeRaw(req)
    }

    func updateNode(id: String, fields: [String: Any]) async throws -> LobbyNode {
        var req = try await buildRequest("PATCH", "/lobby/nodes/\(id)")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: fields)
        struct Wrap: Decodable { let node: LobbyNode }
        return try await execute(req, as: Wrap.self).node
    }

    func deleteNode(id: String) async throws {
        let req = try await buildRequest("DELETE", "/lobby/nodes/\(id)")
        _ = try await executeRaw(req)
    }

    func stop(nodeId: String) async throws {
        let req = try await buildRequest("POST", "/lobby/nodes/\(nodeId)/stop")
        _ = try await executeRaw(req)
    }

    func attach(nodeId: String) async throws {
        var req = try await buildRequest("POST", "/lobby/nodes/\(nodeId)/attach")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = AttachBody(deviceId: mc.deviceId, display: nil)
        req.httpBody = try encoder.encode(body)
        _ = try await executeRaw(req)
    }

    func detach(nodeId: String) async throws {
        var req = try await buildRequest("POST", "/lobby/nodes/\(nodeId)/detach")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["device_id": mc.deviceId])
        _ = try await executeRaw(req)
    }

    /// SSE stream of lobby-wide events.
    nonisolated func eventStream() -> AsyncThrowingStream<LobbyEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @Sendable in
                let url = await self.mc.lobbyURL.appendingPathComponent("lobby/events")
                let key = await self.mc.clientKey
                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue(key, forHTTPHeaderField: "X-PitWall-Key")

                do {
                    let (bytes, response) = try await PinnedURLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode) else {
                        continuation.finish(throwing: LobbyError.server(
                            (response as? HTTPURLResponse)?.statusCode ?? 0,
                            "events stream"))
                        return
                    }

                    var eventType = ""
                    var dataLines: [String] = []
                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        } else if line.isEmpty {
                            let dataBuf = dataLines.joined(separator: "\n")
                            if !eventType.isEmpty, let payload = dataBuf.data(using: .utf8) {
                                continuation.yield(LobbyEvent(type: eventType, payload: payload))
                            }
                            eventType = ""
                            dataLines = []
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: LobbyError.network(error))
                }
            }
        }
    }

    // MARK: - private

    private func buildRequest(_ method: String, _ path: String) async throws -> URLRequest {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = await mc.lobbyURL.appendingPathComponent(trimmedPath)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(await mc.clientKey, forHTTPHeaderField: "X-PitWall-Key")
        req.timeoutInterval = 10
        return req
    }

    private func executeRaw(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await PinnedURLSession.shared.data(for: request)
        } catch {
            throw LobbyError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw LobbyError.network(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw LobbyError.server(http.statusCode, msg)
        }
        return data
    }

    private func execute<T: Decodable>(_ request: URLRequest, as: T.Type) async throws -> T {
        let data = try await executeRaw(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LobbyError.decoding(error)
        }
    }
}

struct LobbyEvent: Sendable {
    let type: String
    let payload: Data
}
