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
    private let haptics = HapticsManager.shared
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
                    self.applyStateWithHaptics(newState: captured)
                    self.persistState(captured)
                }
            }
            await MainActor.run {
                if self.connectionStatus != .disconnected {
                    self.connectionStatus = .error
                    self.error = "Stream disconnected"
                    self.haptics.serverStatusChange(isNegative: true)
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

    // MARK: - Haptics on state changes

    @MainActor
    private func applyStateWithHaptics(newState: LiveState) {
        let prev = liveState

        // Detect position changes
        if let prevRigs = prev?.rigs {
            for rig in newState.rigs where rig.status == .occupied {
                if let prevRig = prevRigs.first(where: { $0.id == rig.id }),
                   prevRig.position != rig.position {
                    haptics.positionChange()
                    break
                }
            }
        }

        // Detect session starts (newly occupied rigs)
        if let prevRigs = prev?.rigs {
            for rig in newState.rigs where rig.status == .occupied {
                if let prevRig = prevRigs.first(where: { $0.id == rig.id }),
                   prevRig.status != .occupied {
                    haptics.sessionStart()
                    break
                }
            }

            // Detect session ends (rigs no longer occupied)
            for prevRig in prevRigs where prevRig.status == .occupied {
                if let current = newState.rigs.first(where: { $0.id == prevRig.id }),
                   current.status != .occupied {
                    haptics.sessionEnd()
                    break
                }
            }
        }

        // Detect new personal bests
        if let prevRigs = prev?.rigs {
            for rig in newState.rigs {
                if let prevRig = prevRigs.first(where: { $0.id == rig.id }),
                   let newBest = rig.bestLapMs,
                   let prevBest = prevRig.bestLapMs,
                   newBest < prevBest {
                    haptics.newPersonalBest()
                    break
                }
            }
        }

        // Detect server status change
        if let prevServer = prev?.server, prevServer.status != newState.server.status {
            let isNegative = newState.server.status == .stopped || newState.server.status == .stopping
            haptics.serverStatusChange(isNegative: isNegative)
        }

        liveState = newState
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
