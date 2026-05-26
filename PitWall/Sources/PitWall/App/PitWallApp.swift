import SwiftUI

// Note: @main is intentionally omitted here so this code compiles as a
// Swift Package library target (used for testing via `swift test`).
// When the .xcodeproj is created, this struct is set as the app entry point
// in the target's build settings (SWIFT_ACTIVE_COMPILATION_CONDITIONS → PITWALL_APP).
// The entry point is activated at the bottom of this file.
struct PitWallApp: App {
    @State private var authManager = AuthManager()
    @State private var dashboardViewModel: DashboardViewModel

    init() {
        let auth = AuthManager()
        _authManager = State(initialValue: auth)
        _dashboardViewModel = State(initialValue: DashboardViewModel(authManager: auth))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(dashboardViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
