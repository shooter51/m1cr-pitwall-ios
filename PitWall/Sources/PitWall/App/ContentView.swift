import SwiftUI

struct ContentView: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedTab: SidebarTab = .rigs

    var body: some View {
        Group {
            if store.current == nil {
                BackendPickerView()
            } else if mc.attached != nil {
                attachedView
            } else {
                LobbyView()
            }
        }
    }

    @ViewBuilder
    private var attachedView: some View {
        HStack(spacing: 0) {
            PWSidebar(
                selected: $selectedTab,
                showWall: mc.attachedIsOrg,
                locationName: mc.attached?.name ?? "PITWALL"
            )

            ZStack {
                PW.carbon.ignoresSafeArea()
                detailView(for: selectedTab)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func detailView(for tab: SidebarTab) -> some View {
        switch tab {
        case .rigs:        RigGridView()
        case .race:        RaceControlView()
        case .wall:        RaceWallView()
        case .competition: CompetitionView()
        case .broadcast:   BroadcastView()
        case .analytics:   AnalyticsView()
        case .server:      ServerControlView()
        case .settings:    SettingsView()
        }
    }
}
