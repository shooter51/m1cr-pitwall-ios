import Foundation

enum SSEError: Error, LocalizedError {
    case invalidURL
    case connectionFailed(Error)
    case streamTerminated

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid SSE URL."
        case .connectionFailed(let e): return "Connection failed: \(e.localizedDescription)"
        case .streamTerminated: return "SSE stream terminated unexpectedly."
        }
    }
}

actor SSEClient {
    private var task: URLSessionDataTask?
    private var isCancelled = false
    private let reconnectDelayBase: Double = 1.5
    private let maxReconnectDelay: Double = 30.0

    func connect(url: URL, headers: [String: String]) -> AsyncStream<LiveState> {
        AsyncStream { continuation in
            Task {
                await self.startStreaming(url: url, headers: headers, continuation: continuation)
            }

            continuation.onTermination = { [weak self] _ in
                Task { await self?.disconnect() }
            }
        }
    }

    func disconnect() {
        isCancelled = true
        task?.cancel()
        task = nil
    }

    // MARK: - Private

    private func startStreaming(
        url: URL,
        headers: [String: String],
        continuation: AsyncStream<LiveState>.Continuation
    ) async {
        var attempt = 0

        while !isCancelled {
            do {
                try await streamOnce(url: url, headers: headers, continuation: continuation)
                attempt = 0 // Reset on clean close
            } catch {
                if isCancelled { break }
                let delay = min(reconnectDelayBase * pow(2.0, Double(attempt)), maxReconnectDelay)
                attempt += 1
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        continuation.finish()
    }

    private func streamOnce(
        url: URL,
        headers: [String: String],
        continuation: AsyncStream<LiveState>.Continuation
    ) async throws {
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SSEError.streamTerminated
        }

        var eventType = ""
        var dataBuffer = ""

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for try await line in bytes.lines {
            if isCancelled { break }

            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataBuffer = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if line.isEmpty {
                // Dispatch event on blank line
                if !dataBuffer.isEmpty, let data = dataBuffer.data(using: .utf8) {
                    if eventType == "snapshot" || eventType.isEmpty {
                        if let state = try? decoder.decode(LiveState.self, from: data) {
                            continuation.yield(state)
                        }
                    }
                }
                eventType = ""
                dataBuffer = ""
            }
        }
    }
}
