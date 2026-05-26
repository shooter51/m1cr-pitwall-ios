import SwiftUI

struct AnalyticsView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(MCClient.self) private var mc
    @State private var sessions: [Session] = []
    @State private var laps: [LapTime] = []
    @State private var isLoading = false
    @State private var error: String?

    private var api: PitWallAPI {
        PitWallAPI(mc: mc)
    }

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            if isLoading && sessions.isEmpty {
                ProgressView()
                    .tint(PW.guards)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                        kpiHeroStrip
                        hourlyChartSection
                        trackPopularitySection
                        vehicleClassSection
                        equipmentHealthSection
                        returningDriversSection
                    }
                    .padding(PW.cardPadding)
                }
            }
        }
        .navigationTitle("Analytics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await loadData() }
    }

    // MARK: - KPI Hero Strip

    private var kpiHeroStrip: some View {
        let revenue = Double(sessions.filter { $0.status == .completed }.count) * 35.0
        let driverCount = Set(sessions.map { $0.driverName }).count
        let avgSession = sessions.isEmpty ? 0 :
            sessions.compactMap { $0.durationMinutes }.reduce(0, +) / max(1, sessions.compactMap { $0.durationMinutes }.count)
        let utilization = viewModel.activeSessionCount > 0 && viewModel.liveState != nil
            ? Double(viewModel.activeSessionCount) / Double(max(1, viewModel.liveState?.rigs.count ?? 1))
            : 0.0

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PW.gridGap) {
                KPIHeroCard(label: "REVENUE", value: String(format: "£%.0f", revenue), accent: PW.ok)
                KPIHeroCard(label: "DRIVERS", value: "\(driverCount)", accent: PW.silver)
                KPIHeroCard(label: "LAPS", value: "\(laps.count)", accent: PW.info)
                KPIHeroCard(label: "AVG SESSION", value: "\(avgSession)m", accent: PW.silver)
                KPIHeroCard(
                    label: "UTILIZATION",
                    value: String(format: "%.0f%%", utilization * 100),
                    accent: utilization > 0.7 ? PW.ok : (utilization > 0.4 ? PW.warn : PW.guards)
                )
            }
        }
    }

    // MARK: - Hourly chart

    private var hourlyChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("CUSTOMERS PER HOUR")

            let hourlyData = buildHourlyData()
            let maxCount = hourlyData.values.max() ?? 1

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(hourlyData.keys.sorted(), id: \.self) { hour in
                    let count = hourlyData[hour] ?? 0
                    let ratio = Double(count) / Double(maxCount)

                    VStack(spacing: 4) {
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(PW.silverDim)
                        }

                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(isCurrentHour(hour) ? PW.guards : PW.info.opacity(0.7))
                                    .frame(height: max(2, geo.size.height * ratio))
                            }
                        }

                        Text(String(format: "%02d", hour))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(PW.silverDim)
                    }
                }
            }
            .frame(height: 120)
            .padding(.horizontal, 4)
        }
        .padding(PW.cardPadding)
        .background(PW.panel)
    }

    // MARK: - Track popularity

    private var trackPopularitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("TRACK POPULARITY")

            let trackCounts = Dictionary(grouping: laps, by: { $0.trackName })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }

            let maxCount = trackCounts.first?.value ?? 1

            if trackCounts.isEmpty {
                emptyState("No lap data")
            } else {
                VStack(spacing: 8) {
                    ForEach(trackCounts.prefix(6), id: \.key) { track, count in
                        HStack(spacing: 10) {
                            Text(track)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(PW.silver)
                                .frame(width: 160, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(PW.panel2)
                                    Rectangle()
                                        .fill(PW.info)
                                        .frame(width: geo.size.width * (Double(count) / Double(maxCount)))
                                }
                            }
                            .frame(height: 18)

                            Text("\(count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(PW.silverDim)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(PW.cardPadding)
        .background(PW.panel)
    }

    // MARK: - Vehicle class distribution

    private var vehicleClassSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("VEHICLE CLASS DISTRIBUTION")

            let classCounts = Dictionary(grouping: laps, by: { $0.vehicleClass })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }

            let total = max(1, classCounts.reduce(0) { $0 + $1.value })
            let classColors: [Color] = [PW.guards, PW.info, PW.ok, PW.warn, PW.silverMid]

            if classCounts.isEmpty {
                emptyState("No lap data")
            } else {
                VStack(spacing: 8) {
                    // Stacked bar
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(classCounts.enumerated().prefix(5)), id: \.offset) { idx, pair in
                                Rectangle()
                                    .fill(classColors[idx % classColors.count])
                                    .frame(width: geo.size.width * (Double(pair.value) / Double(total)))
                            }
                        }
                    }
                    .frame(height: 24)

                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(Array(classCounts.enumerated().prefix(5)), id: \.offset) { idx, pair in
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(classColors[idx % classColors.count])
                                    .frame(width: 10, height: 10)
                                Text(pair.key.uppercased())
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(PW.silverMid)
                                Text("(\(pair.value))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(PW.silverDim)
                            }
                        }
                    }
                }
            }
        }
        .padding(PW.cardPadding)
        .background(PW.panel)
    }

    // MARK: - Equipment health grid

    private var equipmentHealthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EQUIPMENT HEALTH")

            let rigs = viewModel.liveState?.rigs ?? []

            if rigs.isEmpty {
                emptyState("No rig data")
            } else {
                let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: PW.gridGap)]
                LazyVGrid(columns: columns, spacing: PW.gridGap) {
                    ForEach(rigs) { rig in
                        rigHealthCard(rig: rig)
                    }
                }
            }
        }
        .padding(PW.cardPadding)
        .background(PW.panel)
    }

    private func rigHealthCard(rig: LiveRig) -> some View {
        let health = healthScore(rig: rig)
        let color: Color = health >= 80 ? PW.ok : (health >= 50 ? PW.warn : PW.guards)

        return VStack(alignment: .leading, spacing: 6) {
            Text(rig.label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(PW.silver)

            Text("\(health)%")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(color)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(PW.panel2)
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * (Double(health) / 100.0))
                }
            }
            .frame(height: 4)

            Text(rig.status.rawValue.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(statusColor(rig.status))
        }
        .padding(10)
        .background(PW.panel2)
    }

    // MARK: - Returning drivers

    private var returningDriversSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RETURNING DRIVERS")

            let driverFrequency = Dictionary(grouping: sessions, by: { $0.driverName })
                .mapValues { $0.count }
                .filter { $0.value > 1 }
                .sorted { $0.value > $1.value }

            if driverFrequency.isEmpty {
                emptyState("No returning drivers today")
            } else {
                VStack(spacing: 0) {
                    ForEach(driverFrequency.prefix(8), id: \.key) { name, count in
                        HStack {
                            Text(name)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(PW.silver)
                            Spacer()
                            Text("\(count) sessions")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(PW.silverDim)
                        }
                        .padding(.vertical, 8)
                        Divider().background(PW.line)
                    }
                }
            }
        }
        .padding(PW.cardPadding)
        .background(PW.panel)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(PW.silverDim)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(PW.silverDim)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }

    private func buildHourlyData() -> [Int: Int] {
        var hours: [Int: Int] = [:]
        for h in 9...22 { hours[h] = 0 }  // 9am to 10pm

        for session in sessions {
            let date = Date(timeIntervalSince1970: Double(session.startedAt))
            let hour = Calendar.current.component(.hour, from: date)
            if (9...22).contains(hour) {
                hours[hour, default: 0] += 1
            }
        }
        return hours
    }

    private func isCurrentHour(_ hour: Int) -> Bool {
        Calendar.current.component(.hour, from: Date()) == hour
    }

    private func healthScore(rig: LiveRig) -> Int {
        switch rig.status {
        case .available: return 100
        case .occupied: return 90
        case .maintenance: return 40
        case .offline: return 0
        }
    }

    private func statusColor(_ status: Rig.RigStatus) -> Color {
        switch status {
        case .available: return PW.ok
        case .occupied: return PW.guards
        case .maintenance: return PW.warn
        case .offline: return PW.silverDim
        }
    }

    // MARK: - Data loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            async let fetchedSessions = api.sessions(filter: SessionFilter(limit: 100))
            async let fetchedLaps = api.laps(filter: LapFilter(period: "today", limit: 500))
            sessions = try await fetchedSessions
            laps = try await fetchedLaps
        } catch let e as APIError {
            switch e {
            case .notAttached:
                error = "No Mobile Command attached"
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

// MARK: - KPI Hero Card

struct KPIHeroCard: View {
    let label: String
    let value: String
    var accent: Color = PW.silver

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(PW.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 3)
        }
    }
}
