import SwiftUI

enum Tab: String, CaseIterable {
    case rigs = "Rigs"
    case raceControl = "Race Control"
    case raceWall = "Race Wall"
    case competition = "Competition"
    case broadcast = "Broadcast"
    case analytics = "Analytics"
    case server = "Server"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .rigs: return "square.grid.2x2"
        case .raceControl: return "flag.checkered"
        case .raceWall: return "rectangle.3.group.fill"
        case .competition: return "trophy"
        case .broadcast: return "video"
        case .analytics: return "chart.bar"
        case .server: return "server.rack"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedTab: Tab? = .rigs
    @State private var showAISheet = false

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

    private var tabsForKind: [Tab] {
        let all = Tab.allCases
        return mc.attachedIsOrg ? all : all.filter { $0 != .raceWall }
    }

    @ViewBuilder
    private var attachedView: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Operations") {
                    ForEach([Tab.rigs, .raceControl, .competition], id: \.self) { tab in
                        if tabsForKind.contains(tab) {
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                }
                Section("Media") {
                    ForEach([Tab.broadcast, .raceWall], id: \.self) { tab in
                        if tabsForKind.contains(tab) {
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                    }
                }
                Section("Insights") {
                    Label(Tab.analytics.rawValue, systemImage: Tab.analytics.icon).tag(Tab.analytics)
                }
                Section("System") {
                    Label(Tab.server.rawValue, systemImage: Tab.server.icon).tag(Tab.server)
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon).tag(Tab.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(mc.attached?.name ?? "PitWall")
            .toolbar {
                ToolbarItem {
                    Button { showAISheet = true } label: {
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("AI Assistant")
                }
            }
        } detail: {
            detailView(for: selectedTab ?? .rigs)
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
        case .rigs:        RigGridView()
        case .raceControl: RaceControlView()
        case .raceWall:    RaceWallView()
        case .competition: CompetitionView()
        case .broadcast:   BroadcastView()
        case .analytics:   AnalyticsView()
        case .server:      ServerControlView()
        case .settings:    SettingsView()
        }
    }
}
