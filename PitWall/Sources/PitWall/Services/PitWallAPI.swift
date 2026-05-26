import Foundation

enum APIError: Error, LocalizedError {
    case notAttached
    case badURL
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAttached: return "No Mobile Command attached. Open the lobby."
        case .badURL: return "Invalid URL."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        }
    }
}

/// HTTP client for the currently-attached Mobile Command.
/// Reads the attached MC's URL and the shared client key off `MCClient`.
actor PitWallAPI {
    private let mc: MCClient

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(mc: MCClient) {
        self.mc = mc
    }

    // MARK: - Rigs

    func rigs() async throws -> [Rig] {
        try await get("/api/pitwall/rigs")
    }

    func createRig(id: String, label: String, qrCodeId: String? = nil, ipAddress: String? = nil) async throws -> Rig {
        var body: [String: Any] = ["id": id, "label": label]
        if let q = qrCodeId { body["qr_code_id"] = q }
        if let ip = ipAddress { body["ip_address"] = ip }
        struct Wrap: Decodable { let rig: Rig }
        let w: Wrap = try await post("/api/pitwall/rigs", body: body)
        return w.rig
    }

    func updateRig(id: String, fields: [String: Any]) async throws -> Rig {
        struct Wrap: Decodable { let rig: Rig }
        let w: Wrap = try await send(method: "PATCH", path: "/api/pitwall/rigs/\(id)", body: fields)
        return w.rig
    }

    func deleteRig(id: String) async throws {
        let _: [String: Bool] = try await send(method: "DELETE", path: "/api/pitwall/rigs/\(id)", body: [:])
    }

    // MARK: - Sessions

    func sessions(filter: SessionFilter? = nil) async throws -> [Session] {
        try await get("/api/pitwall/sessions", queryItems: filter?.queryItems)
    }

    func startSession(_ params: StartSessionParams) async throws -> Session {
        try await post("/api/pitwall/sessions", body: params.body)
    }

    func endSession(id: String) async throws -> [String: Bool] {
        try await post("/api/pitwall/sessions/\(id)/end", body: [:])
    }

    // MARK: - Laps

    func laps(filter: LapFilter? = nil) async throws -> [LapTime] {
        try await get("/api/pitwall/laps", queryItems: filter?.queryItems)
    }

    // MARK: - Competitions

    func competitions() async throws -> [Competition] {
        try await get("/api/pitwall/competitions")
    }

    func createCompetition(_ params: CreateCompetitionParams) async throws -> Competition {
        try await post("/api/pitwall/competitions", body: params.body)
    }

    // MARK: - Race Wall

    func raceWallPostings() async throws -> [RacePosting] {
        struct Wrapper: Decodable { let postings: [RacePosting] }
        let w: Wrapper = try await get("/api/race-wall")
        return w.postings
    }

    func joinPosting(id: String, driverName: String) async throws {
        let _: [String: Bool] = try await post("/api/race-wall/\(id)/join", body: ["driver_name": driverName])
    }

    func pushPostingToDisplay(id: String, displayId: String) async throws {
        let _: [String: Bool] = try await post("/api/race-wall/\(id)/display", body: ["display_id": displayId])
    }

    // MARK: - Server Control

    func serverStatus() async throws -> ServerStatus {
        try await get("/api/pitwall/server-control")
    }

    func startServer() async throws -> ServerStatus {
        try await post("/api/pitwall/server-control", body: [:])
    }

    // MARK: - AI Chat (SSE streaming)

    func aiChat(messages: [AIMessage]) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task { [mc] in
                do {
                    guard let base = await mc.attachedMCURL else {
                        throw APIError.notAttached
                    }
                    let url = base.appendingPathComponent("api/pitwall/ai")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(await mc.clientKey, forHTTPHeaderField: "X-PitWall-Key")

                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    let messagesData = try encoder.encode(messages)
                    let bodyObj = try JSONSerialization.jsonObject(with: messagesData)
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["messages": bodyObj])

                    let (bytes, response) = try await PinnedURLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode) else {
                        throw APIError.serverError(
                            (response as? HTTPURLResponse)?.statusCode ?? 0,
                            "AI endpoint error"
                        )
                    }

                    var eventType = ""
                    var dataLines: [String] = []

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        } else if line.isEmpty {
                            // Dispatch on blank line; join accumulated data lines.
                            let dataBuffer = dataLines.joined(separator: "\n")
                            if !dataBuffer.isEmpty, let chunkData = dataBuffer.data(using: .utf8) {
                                if let json = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any] {
                                    let chunk = AIChunk(
                                        text: json["text"] as? String,
                                        toolName: json["tool_name"] as? String,
                                        toolStatus: json["tool_status"] as? String,
                                        done: eventType == "done"
                                    )
                                    continuation.yield(chunk)
                                    if eventType == "done" { break }
                                }
                            }
                            dataLines = []
                            eventType = ""
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private helpers

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        let request = try await buildRequest(method: "GET", path: path, queryItems: queryItems)
        return try await execute(request)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try await send(method: "POST", path: path, body: body)
    }

    private func send<T: Decodable>(method: String, path: String, body: [String: Any]) async throws -> T {
        var request = try await buildRequest(method: method, path: path)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await execute(request)
    }

    private func buildRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> URLRequest {
        guard let base = await mc.attachedMCURL else { throw APIError.notAttached }

        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var components = URLComponents(url: base.appendingPathComponent(trimmedPath), resolvingAgainstBaseURL: false)
        if let items = queryItems, !items.isEmpty {
            components?.queryItems = items
        }
        guard let url = components?.url else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(await mc.clientKey, forHTTPHeaderField: "X-PitWall-Key")
        request.timeoutInterval = 10
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await PinnedURLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(http.statusCode, message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
