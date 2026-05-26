import SwiftUI

enum Tab: String, CaseIterable {
    case rigs = "Rigs"
    case raceControl = "Race Control"
    case competition = "Competition"
    case broadcast = "Broadcast"
    case analytics = "Analytics"
    case server = "Server"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .rigs: return "square.grid.2x2"
        case .raceControl: return "flag.checkered"
        case .competition: return "trophy"
        case .broadcast: return "video"
        case .analytics: return "chart.bar"
        case .server: return "server.rack"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedTab: Tab = .rigs
    @State private var showAISheet = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainView
            } else {
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private var mainView: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationTitle("PitWall")
            .toolbar {
                ToolbarItem {
                    Button {
                        showAISheet = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                }
            }
        } detail: {
            detailView(for: selectedTab)
        }
        .sheet(isPresented: $showAISheet) {
            AIOperatorView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PW.panel)
        }
    }

    @ViewBuilder
    private func detailView(for tab: Tab) -> some View {
        switch tab {
        case .rigs:
            RigGridView()
        case .raceControl:
            RaceControlView()
        case .competition:
            CompetitionView()
        case .broadcast:
            BroadcastView()
        case .analytics:
            AnalyticsView()
        case .server:
            ServerControlView()
        case .settings:
            SettingsView()
        }
    }
}
