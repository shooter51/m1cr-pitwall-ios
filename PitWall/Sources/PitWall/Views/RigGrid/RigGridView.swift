import SwiftUI

struct RigGridView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var selectedRig: LiveRig?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: PW.gridGap),
    ]

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            VStack(spacing: 0) {
                kpiStrip
                    .padding(.horizontal, PW.cardPadding)
                    .padding(.vertical, 12)
                    .background(PW.panel)

                if let state = viewModel.liveState {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: PW.gridGap) {
                            ForEach(state.rigs) { rig in
                                RigCardView(rig: rig)
                                    .onTapGesture { selectedRig = rig }
                            }
                        }
                        .padding(PW.gridGap)
                    }
                } else {
                    emptyState
                }
            }
        }
        .navigationTitle("Rig Grid")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
        HStack(spacing: 16) {
            KPITile(label: "ACTIVE", value: "\(viewModel.activeSessionCount)")
            KPITile(label: "AVAILABLE", value: "\(viewModel.availableRigCount)")
            KPITile(label: "BEST LAP", value: formatLap(viewModel.bestLapToday))
            Spacer()
            serverStatusPill
            connectionIndicator
        }
    }

    private var serverStatusPill: some View {
        HStack(spacing: 6) {
            StatusDot(status: viewModel.serverStatus)
            Text(viewModel.serverStatus.displayName.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverMid)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PW.panel2)
    }

    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.connectionStatus == .connected ? PW.ok : PW.guards)
                .frame(width: 6, height: 6)
            Text(viewModel.connectionStatus.rawValue.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            if viewModel.connectionStatus == .connecting {
                ProgressView()
                    .tint(PW.guards)
                Text("Connecting to PitWall…")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
            } else if let error = viewModel.error {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(PW.warn)
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(PW.silverMid)
                Button("Retry") { viewModel.connect() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Text("No live data")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func formatLap(_ ms: Int?) -> String {
        guard let ms else { return "--:--.---" }
        let m = ms / 60_000
        let s = Double(ms % 60_000) / 1000.0
        return String(format: "%d:%06.3f", m, s)
    }
}

// MARK: - Rig Detail Sheet placeholder

struct RigDetailSheet: View {
    let rig: LiveRig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PW.carbon.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(rig.label)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(PW.silver)
                    Text(rig.location)
                        .font(.system(size: 14))
                        .foregroundStyle(PW.silverMid)
                    Divider().background(PW.line)
                    if let driver = rig.driverName {
                        LabeledValue(label: "DRIVER", value: driver)
                    }
                    if let bestLap = rig.bestLapMs {
                        LabeledValue(label: "BEST LAP", value: formatLap(bestLap))
                    }
                    if let lastLap = rig.lastLapMs {
                        LabeledValue(label: "LAST LAP", value: formatLap(lastLap))
                    }
                    Spacer()
                    Text("Full detail view — Phase 2")
                        .font(.system(size: 12))
                        .foregroundStyle(PW.silverDim)
                }
                .padding(PW.cardPadding)
            }
            .navigationTitle("Rig Detail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatLap(_ ms: Int) -> String {
        let m = ms / 60_000
        let s = Double(ms % 60_000) / 1000.0
        return String(format: "%d:%06.3f", m, s)
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(PW.silver)
        }
    }
}
