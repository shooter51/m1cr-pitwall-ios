import SwiftUI

struct RaceControlView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(MCClient.self) private var mc
    @State private var posting = false
    @State private var posted = false
    @State private var postError: String?

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            if let state = viewModel.liveState {
                liveLayout(state: state)
            } else {
                Text("Waiting for live data…")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
            }
        }
        .navigationTitle("Race Control")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { postToParentToolbar }
        .alert("Post failed", isPresented: .init(
            get: { postError != nil },
            set: { if !$0 { postError = nil } }
        )) {
            Button("OK") { postError = nil }
        } message: {
            Text(postError ?? "")
        }
    }

    @ToolbarContentBuilder
    private var postToParentToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if mc.attached?.parentId != nil && mc.attached?.kind == .location {
                Button {
                    Task { await postToParent() }
                } label: {
                    Label(posted ? "Posted" : "Post to Parent", systemImage: posted ? "checkmark.circle.fill" : "arrow.up.right.square")
                }
                .disabled(posting || posted)
            }
        }
    }

    private func postToParent() async {
        guard let base = mc.attachedMCURL, let state = viewModel.liveState else { return }
        posting = true; defer { posting = false }
        var req = URLRequest(url: base.appendingPathComponent("api/postings"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mc.authorize(&req)
        let body: [String: Any] = [
            "track_id":      state.track.id,
            "track_name":    state.track.name,
            "vehicle_class": "GT3",   // refine later: derive from current session
            "slot_total":    state.rigs.count,
            "slot_open":     max(0, state.rigs.count - state.rigs.filter { $0.status == .occupied }.count),
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                posted = true
            } else {
                postError = "Post failed: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            }
        } catch {
            postError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func liveLayout(state: LiveState) -> some View {
        HStack(spacing: 0) {
            // Left column — session info
            VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                sessionPhaseBlock(state.session)
                trackBlock(state.track)
                Spacer()
            }
            .frame(width: 200)
            .padding(PW.cardPadding)
            .background(PW.panel)

            Divider().background(PW.line)

            // Center — timing table
            timingTable(rigs: state.rigs)

            Divider().background(PW.line)

            // Right column — server + broadcast info
            VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                serverBlock(state.server)
                if let comp = state.competition {
                    competitionBlock(comp)
                }
                Spacer()
            }
            .frame(width: 200)
            .padding(PW.cardPadding)
            .background(PW.panel)
        }
    }

    // MARK: - Column sub-views

    private func sessionPhaseBlock(_ session: LiveState.SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PHASE")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Text(session.phase.uppercased())
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PW.silver)
            Text(formatTime(session.timeLeftS))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(PW.guards)
        }
    }

    private func trackBlock(_ track: LiveState.Track) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRACK")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Text(track.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PW.silver)
            Text(track.weather.uppercased())
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(PW.info)
        }
    }

    private func serverBlock(_ server: LiveState.ServerInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SERVER")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            HStack(spacing: 6) {
                StatusDot(status: server.status)
                Text(server.status.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PW.silverMid)
            }
        }
    }

    private func competitionBlock(_ comp: Competition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COMPETITION")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Text(comp.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PW.silver)
                .lineLimit(2)
        }
    }

    private func timingTable(rigs: [LiveRig]) -> some View {
        let occupied = rigs
            .filter { $0.status == .occupied }
            .sorted { ($0.position ?? 999) < ($1.position ?? 999) }

        return VStack(spacing: 0) {
            // Header row
            HStack {
                Text("POS").frame(width: 36, alignment: .center)
                Text("DRIVER").frame(maxWidth: .infinity, alignment: .leading)
                Text("BEST").frame(width: 90, alignment: .trailing)
                Text("LAST").frame(width: 90, alignment: .trailing)
                Text("GAP").frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(PW.silverDim)
            .padding(.horizontal, PW.cardPadding)
            .padding(.vertical, 8)
            .background(PW.panel2)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(occupied) { rig in
                        timingRow(rig: rig)
                        Divider().background(PW.line)
                    }
                }
            }
        }
    }

    private func timingRow(rig: LiveRig) -> some View {
        HStack {
            Text(rig.position.map { "P\($0)" } ?? "—")
                .frame(width: 36, alignment: .center)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(rig.position == 1 ? PW.guards : PW.silverMid)

            Text((rig.driverName ?? rig.label).uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(PW.silver)
                .lineLimit(1)

            Text(formatLap(rig.bestLapMs))
                .frame(width: 90, alignment: .trailing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PW.ok)

            Text(formatLap(rig.lastLapMs))
                .frame(width: 90, alignment: .trailing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PW.silverMid)

            Text(formatGap(rig.gapToLeaderMs))
                .frame(width: 80, alignment: .trailing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PW.silverDim)
        }
        .padding(.horizontal, PW.cardPadding)
        .padding(.vertical, 8)
        .background(rig.position == 1 ? PW.guards.opacity(0.05) : Color.clear)
        .overlay(alignment: .leading) {
            if rig.position == 1 {
                Rectangle().fill(PW.guards).frame(width: 3)
            }
        }
    }

    // MARK: - Formatting

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }

    private func formatLap(_ ms: Int?) -> String {
        LapTimeFormatter.format(ms)
    }

    private func formatGap(_ ms: Int?) -> String {
        guard let ms else { return "—" }
        if ms == 0 { return "LEADER" }
        let s = Double(ms) / 1000.0
        return String(format: "+%.3fs", s)
    }
}
