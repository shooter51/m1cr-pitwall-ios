import Testing
import Foundation
@testable import PitWall

// MARK: - ServerControl tests
// Tests server status model and API calls.

@Suite("ServerControl")
struct ServerControlTests {
    let baseURL = URL(string: "https://pitwall.m1circuit.com")!

    @MainActor
    private func makeMC() -> MCClient {
        MCClient(clientKey: "test-key", lobbyURL: baseURL, deviceId: "test-device")
    }

    // MARK: - ServerStatus model

    @Test("ServerStatus EC2Status raw values are correct")
    func ec2StatusRawValues() {
        #expect(ServerStatus.EC2Status.running.rawValue == "running")
        #expect(ServerStatus.EC2Status.stopped.rawValue == "stopped")
        #expect(ServerStatus.EC2Status.starting.rawValue == "starting")
        #expect(ServerStatus.EC2Status.stopping.rawValue == "stopping")
    }

    @Test("ServerStatus isTransitioning is true only for starting/stopping")
    func ec2StatusTransitioning() {
        #expect(ServerStatus.EC2Status.starting.isTransitioning == true)
        #expect(ServerStatus.EC2Status.stopping.isTransitioning == true)
        #expect(ServerStatus.EC2Status.running.isTransitioning == false)
        #expect(ServerStatus.EC2Status.stopped.isTransitioning == false)
    }

    @Test("ServerStatus displayName returns capitalized string")
    func ec2StatusDisplayName() {
        #expect(ServerStatus.EC2Status.running.displayName == "Running")
        #expect(ServerStatus.EC2Status.stopped.displayName == "Stopped")
        #expect(ServerStatus.EC2Status.starting.displayName == "Starting")
        #expect(ServerStatus.EC2Status.stopping.displayName == "Stopping")
    }

    @Test("ServerStatus decodes from JSON")
    func serverStatusDecoding() throws {
        let json = """
        {"status": "running", "ip": "10.0.0.1"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let status = try decoder.decode(ServerStatus.self, from: json)

        #expect(status.status == .running)
        #expect(status.ip == "10.0.0.1")
    }

    @Test("ServerStatus decodes with null IP")
    func serverStatusDecodingNullIP() throws {
        let json = """
        {"status": "stopped", "ip": null}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let status = try decoder.decode(ServerStatus.self, from: json)

        #expect(status.status == .stopped)
        #expect(status.ip == nil)
    }

    // MARK: - API calls (require MC attachment)

    @MainActor
    @Test("serverStatus() throws when not attached")
    func serverStatusRequiresAttachment() async throws {
        let mc = makeMC()
        let api = PitWallAPI(mc: mc)

        await #expect(throws: APIError.self) {
            try await api.serverStatus()
        }
    }

    @MainActor
    @Test("startServer() throws when not attached")
    func startServerRequiresAttachment() async throws {
        let mc = makeMC()
        let api = PitWallAPI(mc: mc)

        await #expect(throws: APIError.self) {
            try await api.startServer()
        }
    }

    // MARK: - DashboardViewModel server status integration

    @MainActor
    @Test("DashboardViewModel.serverStatus falls back to .stopped without live state")
    func serverStatusFallback() {
        let vm = DashboardViewModel(mc: makeMC())
        #expect(vm.serverStatus == .stopped)
    }

    @MainActor
    @Test("DashboardViewModel.serverStatus reads from live state")
    func serverStatusFromLiveState() {
        let vm = DashboardViewModel(mc: makeMC())
        vm.liveState = MockRigProvider.liveState
        #expect(vm.serverStatus == .running)
    }

    // MARK: - LiveState ServerInfo

    @Test("LiveState.ServerInfo decodes correctly")
    func liveStateServerInfoDecoding() throws {
        let json = """
        {"status": "starting"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let info = try decoder.decode(LiveState.ServerInfo.self, from: json)
        #expect(info.status == .starting)
    }
}
