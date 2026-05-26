import SwiftUI

#if PITWALL_APP
@main
#endif
struct PitWallApp: App {
    @State private var store: BackendStore
    @State private var mc: MCClient
    @State private var lobbyVM: LobbyViewModel
    @State private var dashboardViewModel: DashboardViewModel

    init() {
        // Build-time defaults (Secrets.xcconfig) seed a "M1 Circuit" Backend on
        // first launch. Operators can add their own via the Backend picker.
        let buildLobbyURLString = Bundle.main.infoDictionary?["PITWALL_LOBBY_URL"] as? String
        let buildKey = Bundle.main.infoDictionary?["PITWALL_CLIENT_KEY"] as? String

        let seed: Backend? = {
            guard let s = buildLobbyURLString, let url = URL(string: s),
                  let key = buildKey, !key.isEmpty,
                  // Skip any flavor of unset / placeholder.
                  !key.contains("CHANGE"),
                  !key.hasPrefix("DEV-"),
                  !key.hasPrefix("PLACEHOLDER")
            else { return nil }
            return Backend(name: "M1 Circuit", lobbyURL: url, clientKey: key)
        }()

        let store = BackendStore(defaultSeed: seed)
        let deviceId = Self.persistentDeviceId()

        // Initialise MCClient from whichever Backend is current (or a sentinel
        // value if there's none — BackendPickerView is shown before any traffic).
        let current = store.current
        let mc = MCClient(
            clientKey: current?.clientKey ?? "",
            lobbyURL: current?.lobbyURL ?? URL(string: "https://invalid.local")!,
            deviceId: deviceId,
        )
        let lobby = LobbyClient(mc: mc)

        _store = State(initialValue: store)
        _mc = State(initialValue: mc)
        _lobbyVM = State(initialValue: LobbyViewModel(lobby: lobby, mc: mc))
        _dashboardViewModel = State(initialValue: DashboardViewModel(mc: mc))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(mc)
                .environment(lobbyVM)
                .environment(dashboardViewModel)
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 1180, minHeight: 760)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        #endif
    }

    private static func persistentDeviceId() -> String {
        let key = "pitwall.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
