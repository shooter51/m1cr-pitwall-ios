import Foundation

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case badURL
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please log in."
        case .badURL: return "Invalid URL."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        }
    }
}

actor PitWallAPI {
    let baseURL: URL
    private let authManager: AuthManager

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(baseURL: URL = URL(string: "https://pitwall.m1circuit.com")!, authManager: AuthManager) {
        self.baseURL = baseURL
        self.authManager = authManager
    }

    // MARK: - Rigs

    func rigs() async throws -> [Rig] {
        try await get("/api/pitwall/rigs")
    }

    // MARK: - Sessions

    func sessions(filter: SessionFilter? = nil) async throws -> [Session] {
        try await get("/api/pitwall/sessions", queryItems: filter?.queryItems)
    }

    func startSession(_ params: StartSessionParams) async throws -> Session {
        try await post("/api/pitwall/sessions", body: params.body)
    }

    func endSession(id: String) async throws -> Session {
        try await patch("/api/pitwall/sessions", body: ["id": id, "status": "completed"])
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
            Task {
                do {
                    guard let token = await authManager.token else {
                        throw APIError.notAuthenticated
                    }
                    let url = baseURL.appendingPathComponent("/api/pitwall/ai")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    let messagesData = try encoder.encode(messages)
                    let bodyObj = try JSONSerialization.jsonObject(with: messagesData)
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["messages": bodyObj])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode) else {
                        throw APIError.serverError(
                            (response as? HTTPURLResponse)?.statusCode ?? 0,
                            "AI endpoint error"
                        )
                    }

                    var eventType = ""
                    var dataBuffer = ""

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataBuffer = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
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
                            dataBuffer = ""
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
        let request = try buildRequest(method: "GET", path: path, queryItems: queryItems)
        return try await execute(request)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = try buildRequest(method: "POST", path: path)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    private func patch<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = try buildRequest(method: "PATCH", path: path)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    private func buildRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard let token = authManager.token else {
            throw APIError.notAuthenticated
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if let items = queryItems, !items.isEmpty {
            components?.queryItems = items
        }
        guard let url = components?.url else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
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
