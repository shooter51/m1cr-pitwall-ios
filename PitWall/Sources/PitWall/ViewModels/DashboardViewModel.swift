import Foundation
import Observation

enum ConnectionStatus: String, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

@Observable
final class DashboardViewModel {
    var liveState: LiveState?
    var connectionStatus: ConnectionStatus = .disconnected
    var error: String?

    // Derived KPIs
    var activeSessionCount: Int {
        liveState?.rigs.filter { $0.status == .occupied }.count ?? 0
    }

    var availableRigCount: Int {
        liveState?.rigs.filter { $0.status == .available }.count ?? 0
    }

    var bestLapToday: Int? {
        liveState?.rigs.compactMap(\.bestLapMs).min()
    }

    var serverStatus: ServerStatus.EC2Status {
        liveState?.server.status ?? .stopped
    }

    private let api: PitWallAPI
    private let sseClient = SSEClient()
    private let authManager: AuthManager
    private var streamTask: Task<Void, Never>?

    init(authManager: AuthManager, baseURL: URL = URL(string: "https://pitwall.m1circuit.com")!) {
        self.authManager = authManager
        self.api = PitWallAPI(baseURL: baseURL, authManager: authManager)
    }

    // MARK: - Connection lifecycle

    func connect() {
        guard connectionStatus == .disconnected || connectionStatus == .error else { return }
        guard authManager.isAuthenticated, let token = authManager.token else {
            error = "Not authenticated"
            connectionStatus = .error
            return
        }

        connectionStatus = .connecting
        error = nil

        let sseURL = URL(string: "https://pitwall.m1circuit.com/api/pitwall/state")!
        let headers = ["Authorization": "Bearer \(token)"]

        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = await sseClient.connect(url: sseURL, headers: headers)
            await MainActor.run {
                self.connectionStatus = .connected
            }
            for await state in stream {
                let captured = state
                await MainActor.run {
                    self.liveState = captured
                    self.persistState(captured)
                }
            }
            await MainActor.run {
                if self.connectionStatus != .disconnected {
                    self.connectionStatus = .error
                    self.error = "Stream disconnected"
                }
            }
        }
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        Task { await sseClient.disconnect() }
        connectionStatus = .disconnected
    }

    // MARK: - Persistence (cache last known state)

    private let cacheKey = "pitwall.lastLiveState"

    func loadCachedState() {
        guard liveState == nil,
              let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        liveState = try? decoder.decode(LiveState.self, from: data)
    }

    private func persistState(_ state: LiveState) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
