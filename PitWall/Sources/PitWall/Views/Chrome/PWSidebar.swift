import SwiftUI

enum SidebarTab: String, CaseIterable {
    case rigs        = "RIG GRID"
    case race        = "RACE CONTROL"
    case competition = "COMPETITION"
    case broadcast   = "BROADCAST"
    case wall        = "RACE WALL"
    case analytics   = "ANALYTICS"
    case server      = "SERVER"
    case settings    = "SETTINGS"

    var group: String {
        switch self {
        case .rigs, .race, .competition: return "OPERATIONS"
        case .broadcast, .wall: return "MEDIA"
        case .analytics: return "INSIGHTS"
        case .server, .settings: return "SYSTEM"
        }
    }

    var hint: String? {
        switch self {
        case .rigs: return "10"
        case .race: return "LIVE"
        case .competition: return "8"
        case .broadcast: return "AUTO"
        case .wall: return "ORG"
        case .analytics: return nil
        case .server: return "EC2"
        case .settings: return nil
        }
    }

    var hintIsLive: Bool { self == .race }

    var iconName: String {
        switch self {
        case .rigs: return "square.grid.2x2"
        case .race: return "flag.checkered"
        case .competition: return "trophy"
        case .broadcast: return "play.rectangle"
        case .wall: return "rectangle.3.group"
        case .analytics: return "chart.bar"
        case .server: return "server.rack"
        case .settings: return "gear"
        }
    }
}

private struct NavGroup {
    let name: String
    let tabs: [SidebarTab]
}

private let navGroups: [NavGroup] = [
    NavGroup(name: "OPERATIONS", tabs: [.rigs, .race, .competition]),
    NavGroup(name: "MEDIA",      tabs: [.broadcast, .wall]),
    NavGroup(name: "INSIGHTS",   tabs: [.analytics]),
    NavGroup(name: "SYSTEM",     tabs: [.server, .settings]),
]

struct PWSidebar: View {
    @Binding var selected: SidebarTab
    var showWall: Bool = false
    var locationName: String = "LAGUNA SECA"

    var body: some View {
        VStack(spacing: 0) {
            brandBlock
            navBlock
            Spacer(minLength: 0)
            footerBlock
        }
        .frame(width: PW.sidebarWidth)
        .background(PW.carbon2)
        .overlay(alignment: .trailing) {
            Rectangle().fill(PW.line).frame(width: 1)
        }
    }

    // MARK: Brand + location

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // Brand mark
                HStack(spacing: 0) {
                    Text("M1")
                        .font(PW.FontStyle.title(22))
                        .foregroundColor(PW.guards)
                        .tracking(-0.44)
                    Text("·CIRCUIT")
                        .font(PW.FontStyle.title(22))
                        .foregroundColor(PW.silver)
                        .tracking(-0.44)
                }
                .textCase(.uppercase)

                Spacer()

                // AI button
                ZStack {
                    Rectangle()
                        .stroke(PW.guards, lineWidth: 1)
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(PW.guardsBright)
                }
            }

            Spacer().frame(height: 12)

            Text("// ATTACHED")
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundColor(PW.silverDim)
                .tracking(2.2)

            Spacer().frame(height: 4)

            Text(locationName.uppercased())
                .font(PW.FontStyle.title(24))
                .foregroundColor(PW.silver)
                .tracking(-0.48)
                .lineLimit(1)

            Spacer().frame(height: 6)

            HStack(spacing: 6) {
                Circle().fill(PW.ok).frame(width: 6, height: 6)
                Text("LAN · 192.168.1.42")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverMid)
                    .tracking(2.0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }

    // MARK: Nav groups

    private var navBlock: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(navGroups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text("// \(group.name)")
                            .font(PW.FontStyle.mono(9, weight: .bold))
                            .foregroundColor(PW.silverDim)
                            .tracking(2.4)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        ForEach(group.tabs.filter { $0 != .wall || showWall }, id: \.self) { tab in
                            navRow(tab: tab)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(.top, 14)
        }
    }

    private func navRow(tab: SidebarTab) -> some View {
        let isActive = selected == tab
        return Button {
            selected = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isActive ? PW.guardsBright : PW.silverDim)
                    .frame(width: 20, alignment: .center)

                Text(tab.rawValue)
                    .font(PW.FontStyle.mono(11, weight: .bold))
                    .foregroundColor(isActive ? PW.silver : PW.silverMid)
                    .tracking(1.4)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let hint = tab.hint {
                    Text(hint)
                        .font(PW.FontStyle.mono(9, weight: .bold))
                        .foregroundColor(tab.hintIsLive ? PW.guardsBright : PW.silverDim)
                        .tracking(1.6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.leading, -2)  // compensate for border
            .frame(height: PW.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isActive ? PW.guardsBright.opacity(0.08) : Color.clear)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isActive ? PW.guards : Color.clear)
                .frame(width: 2)
        }
    }

    // MARK: Footer

    private var footerBlock: some View {
        HStack(spacing: 10) {
            ZStack {
                Rectangle()
                    .fill(PW.guards)
                    .frame(width: 28, height: 28)
                Text("T")
                    .font(PW.FontStyle.title(14))
                    .foregroundColor(.white)
                    .tracking(-0.28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("TOM GIBSON")
                    .font(PW.FontStyle.mono(11, weight: .semibold))
                    .foregroundColor(PW.silver)
                    .tracking(0.4)

                Text("ADMIN · LAGUNA")
                    .font(PW.FontStyle.mono(8, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.0)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }
}
