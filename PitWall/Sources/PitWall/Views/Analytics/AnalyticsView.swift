import SwiftUI

struct AnalyticsView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(MCClient.self) private var mc
    @State private var sessions: [Session] = []
    @State private var laps: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var api: PitWallAPI?

    private let mockHours: [(h: String, n: Int, cur: Bool)] = [
        ("09", 7, false), ("10", 9, false), ("11", 5, false),
        ("12", 7, false), ("13", 11, false), ("14", 12, false),
        ("15", 10, true),  ("16", 5, false), ("17", 4, false),
        ("18", 3, false), ("19", 8, false), ("20", 9, false),
        ("21", 7, false), ("22", 4, false),
    ]

    private func resolvedAPI() -> PitWallAPI {
        if let api { return api }
        let newAPI = PitWallAPI(mc: mc)
        api = newAPI
        return newAPI
    }

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "06 · INSIGHTS",
                title: "Analytics"
            ) {
                Text("RANGE · TODAY · 15:42 LOCAL")
                PWTopBarDivider()
                Text("SOURCE · LIVE")
            } actions: {
                Button("REFRESH") { Task { await loadData() } }
                    .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                Button("EXPORT") {}
                    .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            }

            kpiStrip

            // Body layout
            GeometryReader { geo in
                HStack(spacing: PW.gap2) {
                    // Left: customers / hour (spans both rows)
                    customersChart
                        .frame(width: geo.size.width * 0.6 - PW.gap2)

                    // Right: top tracks + class/health
                    VStack(spacing: PW.gap2) {
                        tracksSection
                        classMixAndHealth
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(14)
            }
        }
        .background(PW.carbon)
        .task { await loadData() }
    }

    // MARK: - KPI strip

    private var kpiStrip: some View {
        let rigs = viewModel.liveState?.rigs ?? []
        let occupied = rigs.filter { $0.status == .occupied }.count
        let total = max(1, rigs.count)
        let utilPct = Int(Double(occupied) / Double(total) * 100)

        return PWKPIStrip(items: [
            .init(label: "EST. REVENUE", value: "$2,845", aux: "+$420 / HR",
                  accent: PW.ok, color: PW.ok),
            .init(label: "DRIVERS", value: "47", aux: "12 RETURNING",
                  accent: PW.silver, color: PW.silver),
            .init(label: "LAPS", value: "612", aux: "AVG 13.0 / DRIVER",
                  accent: PW.info, color: PW.info),
            .init(label: "AVG SESSION", value: "18m", aux: "BUDGET 20m",
                  accent: PW.silver, color: PW.silver),
            .init(label: "UTILIZATION", value: "\(utilPct)%", aux: "PEAK 15:00 · 100%",
                  accent: PW.ok, color: PW.ok),
        ])
    }

    // MARK: - Customers / hour bar chart

    private var customersChart: some View {
        let maxN = mockHours.map(\.n).max() ?? 1

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("// CUSTOMERS / HOUR")
                    .pwEyebrow()
                Spacer()
                Text("14 HRS · 09 – 22")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(mockHours, id: \.h) { bar in
                        let pct = CGFloat(bar.n) / CGFloat(maxN)
                        VStack(spacing: 6) {
                            Text("\(bar.n)")
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(bar.cur ? PW.guardsBright : PW.silverDim)
                                .tracking(1.0)

                            ZStack {
                                Rectangle()
                                    .fill(bar.cur ? PW.guards : PW.info.opacity(0.7))
                                    .frame(width: .infinity, height: (geo.size.height - 48) * pct)
                            }
                            .frame(maxWidth: .infinity)

                            Text(bar.h)
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(bar.cur ? PW.guardsBright : PW.silverDim)
                                .tracking(1.2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Legend
            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    Rectangle().fill(PW.guards).frame(width: 10, height: 10)
                    Text("CURRENT HR")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.8)
                }
                HStack(spacing: 6) {
                    Rectangle().fill(PW.info.opacity(0.7)).frame(width: 10, height: 10)
                    Text("COMPLETED")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.8)
                }
                Spacer()
                Text("PEAK · 12 DRIVERS @ 14:00")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silver2)
                    .tracking(1.6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(PW.line).frame(height: 1)
            }
        }
        .background(PW.panel)
        .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
    }

    // MARK: - Tracks top 5

    private var tracksSection: some View {
        let tracks: [(name: String, pct: Int, hi: Bool)] = [
            ("LAGUNA SECA", 38, true),
            ("SILVERSTONE GP", 24, false),
            ("SPA", 18, false),
            ("NÜRBURGRING", 12, false),
            ("MONZA", 8, false),
        ]

        return VStack(alignment: .leading, spacing: 0) {
            Text("// TRACKS · TOP 5")
                .pwEyebrow()
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 14)

            VStack(spacing: 8) {
                ForEach(tracks, id: \.name) { track in
                    HStack(spacing: 10) {
                        Text(track.name)
                            .font(PW.FontStyle.mono(10, weight: track.hi ? .semibold : .medium))
                            .foregroundColor(track.hi ? PW.silver : PW.silverMid)
                            .tracking(1.2)
                            .frame(width: 120, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(PW.panel3).frame(height: 8)
                                Rectangle()
                                    .fill(track.hi ? PW.guards : PW.silverMid)
                                    .frame(width: geo.size.width * CGFloat(track.pct) / 50.0, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(track.pct)%")
                            .font(PW.FontStyle.mono(10, weight: .semibold))
                            .foregroundColor(track.hi ? PW.guardsBright : PW.silverMid)
                            .tracking(0.6)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(PW.panel)
        .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Class mix + rig health

    private var classMixAndHealth: some View {
        HStack(alignment: .top, spacing: 16) {
            // Class mix
            VStack(alignment: .leading, spacing: 14) {
                Text("// CLASS MIX")
                    .pwEyebrow()

                let classes: [(name: String, pct: Int, color: Color)] = [
                    ("GT3", 58, PW.guards),
                    ("GT4", 22, PW.info),
                    ("FORMULA", 14, PW.warn),
                    ("ROAD", 6, PW.silverMid),
                ]
                VStack(spacing: 10) {
                    ForEach(classes, id: \.name) { cls in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(cls.name)
                                    .font(PW.FontStyle.mono(10, weight: .medium))
                                    .foregroundColor(PW.silverMid)
                                    .tracking(1.2)
                                Spacer()
                                Text("\(cls.pct)%")
                                    .font(PW.FontStyle.mono(10, weight: .semibold))
                                    .foregroundColor(PW.silver)
                                    .tracking(0.6)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(PW.panel3).frame(height: 6)
                                    Rectangle()
                                        .fill(cls.color)
                                        .frame(width: geo.size.width * CGFloat(cls.pct) / 100.0, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Rig health grid
            VStack(alignment: .leading, spacing: 14) {
                Text("// RIG HEALTH")
                    .pwEyebrow()

                let rigs = viewModel.liveState?.rigs ?? []
                let gridCols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)
                LazyVGrid(columns: gridCols, spacing: 5) {
                    ForEach(rigs) { rig in
                        rigHealthTile(rig: rig)
                    }
                }

                // Legend
                HStack(spacing: 10) {
                    ForEach([
                        ("OCC", PW.guards),
                        ("AVL", PW.ok),
                        ("MNT", PW.warn),
                        ("OFF", PW.silverInk),
                    ], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Rectangle().fill(color).frame(width: 8, height: 8)
                            Text(label)
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.silverMid)
                                .tracking(1.6)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(PW.panel)
        .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
    }

    private func rigHealthTile(rig: LiveRig) -> some View {
        let bg: Color
        let fg: Color
        switch rig.status {
        case .occupied:    bg = PW.guards;    fg = .white
        case .available:   bg = PW.ok;        fg = .white
        case .maintenance: bg = PW.warn;      fg = .black
        case .offline:     bg = PW.silverInk; fg = .white
        }
        let num = rig.label.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init).first ?? 0
        return Text(String(format: "%02d", num))
            .font(PW.FontStyle.mono(10, weight: .bold))
            .foregroundColor(fg)
            .tracking(0.4)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(bg)
    }

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            let currentAPI = resolvedAPI()
            async let fetchedSessions = currentAPI.sessions(filter: SessionFilter(limit: 100))
            async let fetchedLaps = currentAPI.laps(filter: LapFilter(period: "today", limit: 500))
            let (s, l) = try await (fetchedSessions, fetchedLaps)
            guard !Task.isCancelled else { return }
            sessions = s
            laps = l
        } catch let e as APIError {
            switch e {
            case .notAttached:
                error = "Not connected to a location."
            case .serverError(401, _), .serverError(403, _):
                error = "Authentication required"
            default:
                error = e.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - KPI Hero Card (kept for any remaining references)

struct KPIHeroCard: View {
    let label: String
    let value: String
    var accent: Color = PW.silver
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(2.0)
            Text(value)
                .font(PW.FontStyle.telemetry(28))
                .foregroundColor(accent)
            if let footnote {
                Text(footnote)
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(PW.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 3)
        }
    }
}
