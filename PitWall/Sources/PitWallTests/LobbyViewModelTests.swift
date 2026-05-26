import Testing
import Foundation
@testable import PitWall

// MARK: - LobbyViewModel tests
// LobbyViewModel's network-dependent paths (load, attach, rename, delete) require
// a real LobbyClient which uses PinnedURLSession directly. Tests here cover:
//   - Initial state
//   - State transitions that don't require a network response
//   - Event-stream handler routing (handle(_:) dispatches loads for relevant event types)

@Suite("LobbyViewModel")
struct LobbyViewModelTests {

    @MainActor
    private func makeMC() -> MCClient {
        MCClient(
            clientKey: "test-key",
            lobbyURL: URL(string: "https://lobby.test.com")!,
            deviceId: "device-test"
        )
    }

    @MainActor
    private func makeVM() -> LobbyViewModel {
        let mc = makeMC()
        let lobby = LobbyClient(mc: mc)
        return LobbyViewModel(lobby: lobby, mc: mc)
    }

    // MARK: - Initial state

    @MainActor
    @Test("LobbyViewModel starts in idle state")
    func initialStateIsIdle() {
        let vm = makeVM()
        if case .idle = vm.state {
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Expected .idle, got \(vm.state)")
        }
    }

    @MainActor
    @Test("LobbyViewModel starts with empty nodes array")
    func initialNodesEmpty() {
        let vm = makeVM()
        #expect(vm.nodes.isEmpty)
    }

    @MainActor
    @Test("LobbyViewModel starts with empty spawningNodeIds")
    func initialSpawningNodeIdsEmpty() {
        let vm = makeVM()
        #expect(vm.spawningNodeIds.isEmpty)
    }

    // MARK: - stopEventStream

    @MainActor
    @Test("stopEventStream is idempotent when no stream is running")
    func stopEventStreamIdempotent() {
        let vm = makeVM()
        // Should not crash when called without a running stream.
        vm.stopEventStream()
        vm.stopEventStream()
        #expect(Bool(true))
    }

    @MainActor
    @Test("startEventStream then stopEventStream does not crash")
    func startThenStopEventStream() {
        let vm = makeVM()
        vm.startEventStream()
        vm.stopEventStream()
        #expect(Bool(true))
    }

    // MARK: - State enum pattern matching

    @Test("LobbyViewModel.State.idle has no associated value")
    func stateIdleCase() {
        let state = LobbyViewModel.State.idle
        if case .idle = state { #expect(Bool(true)) }
        else { #expect(Bool(false)) }
    }

    @Test("LobbyViewModel.State.loading has no associated value")
    func stateLoadingCase() {
        let state = LobbyViewModel.State.loading
        if case .loading = state { #expect(Bool(true)) }
        else { #expect(Bool(false)) }
    }

    @Test("LobbyViewModel.State.ready has no associated value")
    func stateReadyCase() {
        let state = LobbyViewModel.State.ready
        if case .ready = state { #expect(Bool(true)) }
        else { #expect(Bool(false)) }
    }

    @Test("LobbyViewModel.State.error carries message string")
    func stateErrorCase() {
        let state = LobbyViewModel.State.error("something went wrong")
        if case .error(let msg) = state {
            #expect(msg == "something went wrong")
        } else {
            #expect(Bool(false))
        }
    }

    // MARK: - load() transitions to loading and then error (network unavailable)

    @MainActor
    @Test("load() transitions through loading and lands in error when network unavailable", .disabled("makes real network call — run manually"))
    func loadTransitionsToError() async {
        let vm = makeVM()
        // No network available in test environment; load() should eventually set .error state.
        await vm.load()

        if case .error = vm.state {
            #expect(Bool(true))
        } else if case .ready = vm.state {
            // If network happened to be available and the server replied, .ready is also valid.
            #expect(Bool(true))
        } else {
            #expect(Bool(false), "Unexpected state after load(): \(vm.state)")
        }
    }

    // MARK: - Node lookup helper (used by attach)

    @MainActor
    @Test("Nodes array is empty before first load")
    func nodesEmptyBeforeLoad() {
        let vm = makeVM()
        #expect(vm.nodes.isEmpty)
    }

    // MARK: - createNode error path (no network)

    @MainActor
    @Test("createNode throws when network unavailable", .disabled("makes real network call — run manually"))
    func createNodeThrowsWithoutNetwork() async {
        let vm = makeVM()
        await #expect(throws: (any Error).self) {
            try await vm.createNode(name: "Test", slug: "test", kind: .location)
        }
    }
}
