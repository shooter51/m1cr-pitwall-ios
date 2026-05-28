import SwiftUI

struct AnalyticsView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(MCClient.self) private var mc
    @State private var sessions: [Session] = []
    @State private var laps: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var api: PitWallAPI?

    // Compute hourly distribution from real session data
    private var hourlyData: [(h: String, n: Int, cur: Bool)] {
        let cal = Calendar.current
        let currentHour = cal.component(.hour, from: Date())
        let fmt = ISO8601DateFormatter()
        var counts = [Int: Int]()
        for s in sessions {
            if let d = fmt.date(from: s.startedAt) {
                let h = cal.component(.hour, from: d)
                counts[h, default: 0] += 1
            }
        }
        return (9...22).map { h in
            (h: String(format: "%02d", h), n: counts[h] ?? 0, cur: h == currentHour)
        }
    }

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
        let completed = sessions.filter { $0.status == .completed }.count
        let estRevenue = completed * 35
        let totalLaps = laps.reduce(0) { $0 + ($1.bestLapMs > 0 ? 1 : 0) }
        let driverCount = sessions.count

        return PWKPIStrip(items: [
            .init(label: "EST. REVENUE", value: "$\(estRevenue)",
                  aux: "\(completed) COMPLETED",
                  accent: PW.ok, color: PW.ok),
            .init(label: "DRIVERS", value: "\(driverCount)",
                  aux: nil,
                  accent: PW.silver, color: PW.silver),
            .init(label: "LAPS", value: "\(totalLaps)",
                  aux: driverCount > 0 ? "AVG \(totalLaps / max(1, driverCount)) / DRIVER" : nil,
                  accent: PW.info, color: PW.info),
            .init(label: "AVG SESSION", value: sessions.isEmpty ? "—" : "\(avgSessionMinutes())m",
                  aux: nil,
                  accent: PW.silver, color: PW.silver),
            .init(label: "UTILIZATION", value: "\(utilPct)%",
                  aux: nil,
                  accent: PW.ok, color: PW.ok),
        ])
    }

    private func avgSessionMinutes() -> Int {
        let durations = sessions.compactMap(\.durationMinutes)
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / durations.count
    }

    // MARK: - Customers / hour bar chart

    private var customersChart: some View {
        let maxN = hourlyData.map(\.n).max() ?? 1

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
                    ForEach(hourlyData, id: \.h) { bar in
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
                let peakHour = hourlyData.max(by: { $0.n < $1.n })
                Text(peakHour.map { "PEAK · \($0.n) DRIVERS @ \($0.h):00" } ?? "NO DATA")
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
        // Derive track distribution from real leaderboard data
        var trackCounts = [String: Int]()
        for entry in laps {
            trackCounts[entry.trackName.uppercased(), default: 0] += 1
        }
        let total = max(1, laps.count)
        let sorted = trackCounts.sorted { $0.value > $1.value }.prefix(5)
        let tracks: [(name: String, pct: Int, hi: Bool)] = sorted.isEmpty
            ? [("NO DATA", 0, false)]
            : sorted.enumerated().map { (i, kv) in
                (name: kv.key, pct: Int(Double(kv.value) / Double(total) * 100), hi: i == 0)
            }

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

    private var classDistribution: [(name: String, pct: Int, color: Color)] {
        var classCounts = [String: Int]()
        for entry in laps {
            classCounts[entry.vehicleClass.uppercased(), default: 0] += 1
        }
        let classTotal = max(1, laps.count)
        let classColors: [Color] = [PW.guards, PW.info, PW.warn, PW.silverMid]
        guard !classCounts.isEmpty else { return [("NO DATA", 0, PW.silverDim)] }
        return classCounts.sorted { $0.value > $1.value }.prefix(4).enumerated().map { (i, kv) in
            (name: kv.key, pct: Int(Double(kv.value) / Double(classTotal) * 100),
             color: classColors[min(i, classColors.count - 1)])
        }
    }

    private var classMixAndHealth: some View {
        let classes = classDistribution
        return HStack(alignment: .top, spacing: 16) {
            // Class mix
            VStack(alignment: .leading, spacing: 14) {
                Text("// CLASS MIX")
                    .pwEyebrow()
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
