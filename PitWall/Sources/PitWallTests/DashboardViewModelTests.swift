import Testing
import Foundation
@testable import PitWall

// MARK: - DashboardViewModel tests
// Tests SSE connection logic, derived KPIs, state persistence, and haptics triggers.

@Suite("DashboardViewModel")
struct DashboardViewModelTests {
    let baseURL = URL(string: "https://pitwall.m1circuit.com")!

    // MARK: - Initial state

    @Test("DashboardViewModel starts disconnected")
    func initialConnectionStatus() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        #expect(vm.connectionStatus == .disconnected)
        #expect(vm.liveState == nil)
        #expect(vm.error == nil)
    }

    // MARK: - KPI derived properties with mock data

    @Test("activeSessionCount returns count of occupied rigs")
    func activeSessionCount() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        vm.liveState = MockRigProvider.liveState
        let occupied = MockRigProvider.rigs.filter { $0.status == .occupied }.count
        #expect(vm.activeSessionCount == occupied)
    }

    @Test("availableRigCount returns count of available rigs")
    func availableRigCount() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        vm.liveState = MockRigProvider.liveState
        let available = MockRigProvider.rigs.filter { $0.status == .available }.count
        #expect(vm.availableRigCount == available)
    }

    @Test("bestLapToday returns minimum bestLapMs across all rigs")
    func bestLapToday() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        vm.liveState = MockRigProvider.liveState
        let expected = MockRigProvider.rigs.compactMap(\.bestLapMs).min()
        #expect(vm.bestLapToday == expected)
    }

    @Test("bestLapToday is nil when no rigs have laps")
    func bestLapTodayNil() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        #expect(vm.bestLapToday == nil)
    }

    @Test("serverStatus returns running from mock live state")
    func serverStatusFromLiveState() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        vm.liveState = MockRigProvider.liveState
        #expect(vm.serverStatus == .running)
    }

    @Test("serverStatus returns stopped when no live state")
    func serverStatusFallback() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        #expect(vm.serverStatus == .stopped)
    }

    // MARK: - Connect without auth

    @Test("connect sets error status when not authenticated")
    func connectWithoutAuth() {
        let auth = AuthManager(baseURL: baseURL)
        auth.logout()
        let vm = DashboardViewModel(authManager: auth)
        vm.connect()
        #expect(vm.connectionStatus == .error)
        #expect(vm.error != nil)
    }

    // MARK: - Disconnect

    @Test("disconnect sets status to disconnected")
    func disconnectSetsStatus() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        vm.connectionStatus = .connecting
        vm.disconnect()
        #expect(vm.connectionStatus == .disconnected)
    }

    // MARK: - Persistence (cache)

    @Test("loadCachedState does nothing when liveState is already set")
    func loadCachedStateSkipsWhenPopulated() {
        let auth = AuthManager(baseURL: baseURL)
        let vm = DashboardViewModel(authManager: auth)
        vm.liveState = MockRigProvider.liveState
        let originalTS = vm.liveState?.ts

        vm.loadCachedState()

        // Should not have overwritten existing state
        #expect(vm.liveState?.ts == originalTS)
    }

    // MARK: - HapticsManager

    @Test("HapticsManager.shared is a singleton")
    func hapticsSingleton() {
        let h1 = HapticsManager.shared
        let h2 = HapticsManager.shared
        // Same instance — must be identical
        #expect(h1 === h2)
    }

    @Test("HapticsManager methods do not crash")
    func hapticsMethodsDoNotCrash() {
        let h = HapticsManager.shared
        h.sessionStart()
        h.sessionEnd()
        h.positionChange()
        h.flagChange()
        h.newPersonalBest()
        h.serverStatusChange(isNegative: true)
        h.serverStatusChange(isNegative: false)
        // If we get here, no crash occurred
        #expect(Bool(true))
    }

    // MARK: - ConnectionStatus

    @Test("ConnectionStatus rawValue matches expected strings")
    func connectionStatusRawValues() {
        #expect(ConnectionStatus.disconnected.rawValue == "disconnected")
        #expect(ConnectionStatus.connecting.rawValue == "connecting")
        #expect(ConnectionStatus.connected.rawValue == "connected")
        #expect(ConnectionStatus.error.rawValue == "error")
    }

    // MARK: - Tab switching (no crash)

    @Test("Tab enum has expected cases")
    func tabEnumCases() {
        let tabs = Tab.allCases
        #expect(tabs.contains(.rigs))
        #expect(tabs.contains(.raceControl))
        #expect(tabs.contains(.competition))
        #expect(tabs.contains(.broadcast))
        #expect(tabs.contains(.analytics))
        #expect(tabs.contains(.server))
        #expect(tabs.contains(.settings))
    }

    @Test("Tab icons are non-empty strings")
    func tabIcons() {
        for tab in Tab.allCases {
            #expect(!tab.icon.isEmpty)
        }
    }
}
