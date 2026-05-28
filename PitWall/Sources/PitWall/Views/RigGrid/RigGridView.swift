import SwiftUI

struct RigGridView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedRig: LiveRig?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: PW.gap), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "01 · OPERATIONS",
                title: "Rig Grid"
            ) {
                // Center info
                if let state = viewModel.liveState {
                    Text("SESSION · \(state.session.phase.uppercased())")
                        .foregroundColor(PW.silver2)
                    PWTopBarDivider()
                    Text("ELAPSED · \(formatTime(state.session.elapsedS ?? 0))")
                    PWTopBarDivider()
                    HStack(spacing: 6) {
                        LiveDot()
                        Text("LIVE")
                            .foregroundColor(PW.guardsBright)
                    }
                } else {
                    Text("NO ACTIVE SESSION")
                }
            } actions: {
                Button("FIND") {}
                    .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                Button("NEW SESSION →") {}
                    .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            }

            kpiStrip

            if let state = viewModel.liveState {
                gridContent(state: state)
            } else {
                emptyState
            }

            footerTicker
        }
        .background(PW.carbon)
        .sheet(item: $selectedRig) { rig in
            RigDetailSheet(rig: rig)
        }
        .onAppear {
            viewModel.loadCachedState()
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }

    // MARK: - KPI strip

    private var kpiStrip: some View {
        let rigs = viewModel.liveState?.rigs ?? []
        let occupied = rigs.filter { $0.status == .occupied }.count
        let available = rigs.filter { $0.status == .available }.count
        let bestRig = rigs.filter { $0.bestLapMs != nil }.sorted { ($0.bestLapMs ?? 0) < ($1.bestLapMs ?? 0) }.first

        return PWKPIStrip(items: [
            .init(label: "OCCUPIED", value: "\(occupied)", unit: "/ \(rigs.count)",
                  accent: PW.guards, color: PW.guardsBright),
            .init(label: "AVAILABLE", value: "\(available)", unit: "/ \(rigs.count)",
                  accent: PW.ok, color: PW.ok),
            .init(label: "BEST LAP TODAY", value: formatLap(bestRig?.bestLapMs),
                  aux: bestRig?.driverName?.uppercased(),
                  accent: PW.silver, color: PW.silver),
            .init(label: "SERVER", value: viewModel.serverStatus.displayName.uppercased(),
                  aux: nil,
                  accent: PW.ok, color: PW.ok),
        ])
    }

    // MARK: - Grid

    private func gridContent(state: LiveState) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("// 10 RIGS · PADDOCK A")
                    .pwEyebrow()
                    .padding(.leading, 16)
                Spacer()
                Text("SORT · POSITION ↓")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.8)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 10)

            LazyVGrid(columns: columns, spacing: PW.gap) {
                ForEach(state.rigs) { rig in
                    RigCardView(rig: rig)
                        .onTapGesture { selectedRig = rig }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Footer ticker

    private var footerTicker: some View {
        HStack(spacing: 0) {
            LiveDot()
                .padding(.leading, 18)
            Text("RECENT")
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundColor(PW.guardsBright)
                .tracking(2.0)
                .padding(.leading, 8)

            Spacer().frame(width: 22)

            Text("A. NAVARRO · NEW PB 1:28.432")
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .tracking(1.6)

            Text("·")
                .foregroundColor(PW.silverInk)
                .padding(.horizontal, 12)

            Text("L. ROSSI · IN PIT TIRES+FUEL")
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .tracking(1.6)

            Spacer()

            Text("15:42:18")
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .padding(.trailing, 18)
        }
        .frame(height: 32)
        .background(PW.carbon2)
        .overlay(alignment: .top) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            if viewModel.connectionStatus == .connecting {
                ProgressView()
                    .tint(PW.guards)
                Text("CONNECTING TO PITWALL…")
                    .font(PW.FontStyle.mono(12, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
            } else if let error = viewModel.error {
                Image(systemName: "triangle")
                    .font(.system(size: 28))
                    .foregroundColor(PW.guards)
                Text(error)
                    .font(PW.FontStyle.body(13))
                    .foregroundColor(PW.silverMid)
                    .multilineTextAlignment(.center)
                Button("RETRY") { viewModel.connect() }
                    .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            } else {
                Text("NO ACTIVE RACE SESSION. START A SESSION ON THE SERVER TO SEE LIVE TIMING.")
                    .font(PW.FontStyle.mono(11, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Formatting

    private func formatLap(_ ms: Int?) -> String {
        LapTimeFormatter.format(ms)
    }

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - LiveState session elapsed helper
private extension LiveState.SessionInfo {
    var elapsedS: Int? { nil }
}

// MARK: - Rig Detail Sheet

struct RigDetailSheet: View {
    let rig: LiveRig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Sheet header
                HStack(alignment: .lastTextBaseline) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("RIG")
                            .font(PW.FontStyle.card(22))
                            .foregroundColor(PW.silver)
                        Text(String(format: "%02d", rigNumber))
                            .font(PW.FontStyle.card(26))
                            .foregroundColor(PW.guardsBright)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(PW.FontStyle.mono(11, weight: .semibold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.4)
                }
                .padding(PW.cardPadding)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PW.line).frame(height: 1)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let driver = rig.driverName {
                            detailRow(label: "DRIVER", value: driver.uppercased())
                        }
                        if let bestLap = rig.bestLapMs {
                            detailRow(label: "BEST LAP", value: LapTimeFormatter.format(bestLap),
                                     valueColor: PW.ok)
                        }
                        if let lastLap = rig.lastLapMs {
                            detailRow(label: "LAST LAP", value: LapTimeFormatter.format(lastLap))
                        }
                        if let pos = rig.position {
                            detailRow(label: "POSITION", value: "P\(pos)",
                                     valueColor: pos == 1 ? PW.guards : PW.silver)
                        }
                        if let lap = rig.currentLap {
                            detailRow(label: "CURRENT LAP", value: "\(lap)")
                        }
                    }
                    .padding(PW.cardPadding)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var rigNumber: Int {
        label.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init).first ?? 0
    }

    private var label: String { rig.label }

    private func detailRow(label: String, value: String,
                           valueColor: Color = PW.silver) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(2.0)
            Text(value)
                .font(PW.FontStyle.mono(16, weight: .bold))
                .foregroundColor(valueColor)
        }
    }
}
