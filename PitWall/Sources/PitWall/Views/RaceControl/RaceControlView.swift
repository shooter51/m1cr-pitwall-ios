import SwiftUI

struct RaceControlView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(MCClient.self) private var mc
    @State private var posting = false
    @State private var posted = false
    @State private var postError: String?

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "02 · OPERATIONS",
                title: "Race Control"
            ) {
                if let state = viewModel.liveState {
                    Text("TRACK · \(state.track.name.uppercased())")
                    PWTopBarDivider()
                    Text("WEATHER · \(state.track.weather.uppercased())")
                    PWTopBarDivider()
                    HStack(spacing: 6) {
                        Rectangle().fill(PW.ok).frame(width: 10, height: 10)
                        Text("GREEN FLAG")
                    }
                } else {
                    Text("NO ACTIVE SESSION")
                }
            } actions: {
                Button { Task { await postToParent() } } label: {
                    Text(posted ? "SHARED" : "POST TO WALL")
                }
                .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                .disabled(posting || posted || mc.attached?.parentId == nil)

                Button("RED FLAG") {}
                    .buttonStyle(PrimaryButtonStyle(.danger, compact: true))

                Button("ADVANCE →") {}
                    .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            }

            if let state = viewModel.liveState {
                HStack(spacing: 0) {
                    leftColumn(state: state)
                    Rectangle().fill(PW.line).frame(width: 1)
                    centerTiming(rigs: state.rigs)
                    Rectangle().fill(PW.line).frame(width: 1)
                    rightColumn(state: state)
                }
                .frame(maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .background(PW.carbon)
        .alert("Post failed", isPresented: .init(
            get: { postError != nil },
            set: { if !$0 { postError = nil } }
        )) {
            Button("OK") { postError = nil }
        } message: {
            Text(postError ?? "")
        }
    }

    // MARK: - Left column (session phase)

    private func leftColumn(state: LiveState) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            // Phase + remaining
            VStack(alignment: .leading, spacing: 0) {
                Text("// PHASE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                Text(state.session.phase.uppercased())
                    .font(PW.FontStyle.title(40))
                    .foregroundColor(PW.silver)
                    .tracking(-0.8)
                    .padding(.top, 4)

                Text("REMAINING")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                    .padding(.top, 14)

                Text(formatTime(state.session.timeLeftS))
                    .font(PW.FontStyle.telemetry(38))
                    .foregroundColor(PW.guardsBright)
                    .tracking(0.76)
                    .padding(.top, 2)
            }

            // Progress
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(PW.line).frame(height: 1)
                Text("// PROGRESS")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                    .padding(.top, 10)

                Text("LAP 12 / 20")
                    .font(PW.FontStyle.mono(12, weight: .semibold))
                    .foregroundColor(PW.silver)
                    .tracking(0)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(PW.panel2).frame(height: 4)
                        Rectangle().fill(PW.guards).frame(width: geo.size.width * 0.6, height: 4)
                    }
                }
                .frame(height: 4)
            }

            // Fastest lap + track record
            VStack(alignment: .leading, spacing: 10) {
                Rectangle().fill(PW.line).frame(height: 1)
                lapRecord(label: "FASTEST LAP", time: "1:28.432",
                         note: "A. NAVARRO · L12", color: PW.guardsBright)
                lapRecord(label: "TRACK RECORD", time: "1:21.421",
                         note: "F. OKONKWO · 2026-04-29", color: PW.silver2)
            }

            Spacer()

            // Competition footer
            VStack(alignment: .leading, spacing: 2) {
                Rectangle().fill(PW.line).frame(height: 1).padding(.bottom, 10)
                Text("COMPETITION")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                if let comp = state.competition {
                    Text(comp.name)
                        .font(PW.FontStyle.body(13))
                        .foregroundColor(PW.silver)
                        .fontWeight(.semibold)
                }
                HStack(spacing: 6) {
                    LiveDot(color: PW.guardsBright, size: 6)
                    Text("BROADCASTING")
                        .font(PW.FontStyle.mono(9, weight: .bold))
                        .foregroundColor(PW.guardsBright)
                        .tracking(1.8)
                }
            }
        }
        .padding(20)
        .frame(width: 220)
        .background(PW.panel)
    }

    private func lapRecord(label: String, time: String, note: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(2.2)
            Text(time)
                .font(PW.FontStyle.mono(14, weight: .bold))
                .foregroundColor(color)
            Text(note)
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
        }
    }

    // MARK: - Center timing tower

    private func centerTiming(rigs: [LiveRig]) -> some View {
        let occupied = rigs
            .filter { $0.status == .occupied && $0.position != nil }
            .sorted { ($0.position ?? 999) < ($1.position ?? 999) }
        let leaderBest = occupied.first?.bestLapMs

        return VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                timingHeader("POS",    width: 48)
                timingHeader("DRIVER", flex: true)
                timingHeader("BEST",   width: 110, trailing: true)
                timingHeader("LAST",   width: 110, trailing: true)
                timingHeader("GAP",    width: 100, trailing: true)
                timingHeader("LAP",    width: 70, trailing: true)
            }
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(PW.panel2)
            .overlay(alignment: .bottom) {
                Rectangle().fill(PW.line).frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(occupied.enumerated()), id: \.element.id) { idx, rig in
                        timingRow(rig: rig, isLeader: idx == 0, leaderBest: leaderBest,
                                  zebra: idx % 2 != 0)
                        Rectangle().fill(PW.line).frame(height: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(PW.carbon)
    }

    @ViewBuilder
    private func timingHeader(_ text: String, width: CGFloat? = nil,
                               flex: Bool = false, trailing: Bool = false) -> some View {
        let aligned: Alignment = trailing ? .trailing : .leading
        let label = Text(text)
            .font(PW.FontStyle.mono(9, weight: .semibold))
            .foregroundColor(PW.silverDim)
            .tracking(2.2)
        if flex {
            label.frame(maxWidth: .infinity, alignment: aligned)
        } else if let width {
            label.frame(width: width, alignment: aligned)
        } else {
            label
        }
    }

    private func timingRow(rig: LiveRig, isLeader: Bool, leaderBest: Int?, zebra: Bool) -> some View {
        let gap: Int? = (isLeader || leaderBest == nil) ? nil : (rig.bestLapMs.map { $0 - (leaderBest ?? 0) })

        return HStack(spacing: 0) {
            // POS badge
            HStack(spacing: 0) {
                Text("P\(rig.position ?? 0)")
                    .font(PW.FontStyle.mono(12, weight: .bold))
                    .foregroundColor(isLeader ? .white : PW.silver)
                    .tracking(0.4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isLeader ? PW.guards : PW.panel3)
            }
            .frame(width: 48, alignment: .leading)

            // Driver
            HStack(spacing: 10) {
                Rectangle()
                    .fill(rig.pitStatus == .inPit ? PW.warn : Color.clear)
                    .frame(width: 2, height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text((rig.driverName ?? rig.label).uppercased())
                        .font(PW.FontStyle.mono(13, weight: .semibold))
                        .foregroundColor(PW.silver)
                        .tracking(0.4)
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text("RIG \(rigNum(rig))")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(1.8)
                        if rig.pitStatus == .inPit {
                            Text(" · IN PIT")
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.warn)
                                .tracking(1.8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // BEST
            Text(formatLap(rig.bestLapMs))
                .font(PW.FontStyle.mono(13, weight: .bold))
                .foregroundColor(isLeader ? PW.guardsBright : PW.ok)
                .frame(width: 110, alignment: .trailing)

            // LAST
            Text(formatLap(rig.lastLapMs))
                .font(PW.FontStyle.mono(13, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .frame(width: 110, alignment: .trailing)

            // GAP
            Text(isLeader ? "— LEADER" : formatGap(gap))
                .font(PW.FontStyle.mono(12, weight: .semibold))
                .foregroundColor(isLeader ? PW.silverDim : PW.silver2)
                .frame(width: 100, alignment: .trailing)

            // LAP
            Text("\(rig.currentLap ?? 0)")
                .font(PW.FontStyle.mono(12, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
        .background(isLeader ? PW.guardsBright.opacity(0.07) :
                    zebra ? PW.carbon2 : Color.clear)
        .overlay(alignment: .leading) {
            if isLeader {
                Rectangle().fill(PW.guards).frame(width: 3)
            }
        }
    }

    private func rigNum(_ rig: LiveRig) -> String {
        let n = rig.label.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init).first ?? 0
        return String(format: "%02d", n)
    }

    // MARK: - Right column

    private func rightColumn(state: LiveState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Server status
            VStack(alignment: .leading, spacing: 6) {
                Text("// SERVER")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                HStack(spacing: 8) {
                    LiveDot(color: PW.ok, size: 8)
                    Text("RUNNING")
                        .font(PW.FontStyle.mono(14, weight: .bold))
                        .foregroundColor(PW.silver)
                        .tracking(0.8)
                }

                Text("UPTIME 03:42:18")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.8)
            }

            // Flag state
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(PW.line).frame(height: 1)
                Text("FLAG STATE")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                    .padding(.top, 8)

                HStack(spacing: 4) {
                    flagButton("GR", color: PW.ok, selected: true)
                    flagButton("YL", color: PW.warn, selected: false)
                    flagButton("RD", color: PW.guards, selected: false)
                }
            }

            // Race log
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(PW.line).frame(height: 1)
                Text("// RACE LOG")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    logRow(time: "15:42:01", color: PW.guardsBright, msg: "PB · NAVARRO")
                    logRow(time: "15:41:18", color: PW.silver2, msg: "OVERTAKE · P5→P4")
                    logRow(time: "15:39:44", color: PW.warn, msg: "ROSSI · PIT IN")
                    logRow(time: "15:36:22", color: PW.silverMid, msg: "SC · CLEAR")
                    logRow(time: "15:30:00", color: PW.ok, msg: "GREEN FLAG")
                }
            }

            Spacer()

            // Booking window card
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    LiveDot(color: PW.guardsBright, size: 6)
                    Text("BOOKING WINDOW")
                        .font(PW.FontStyle.mono(9, weight: .bold))
                        .foregroundColor(PW.guardsBright)
                        .tracking(2.2)
                }
                Text("Sprint Race 2 · 16:00")
                    .font(PW.FontStyle.body(12))
                    .foregroundColor(PW.silver)
                    .fontWeight(.semibold)
                Text("8 GUESTS QUEUED")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
            }
            .padding(14)
            .background(PW.carbon2)
            .overlay(
                Rectangle().stroke(PW.guards, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                Rectangle().fill(PW.guards).frame(width: 3)
            }
        }
        .padding(20)
        .frame(width: 220)
        .background(PW.panel)
    }

    private func flagButton(_ label: String, color: Color, selected: Bool) -> some View {
        Text(label)
            .font(PW.FontStyle.mono(11, weight: .bold))
            .foregroundColor(selected ? .black : PW.silverMid)
            .tracking(1.2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? color : PW.panel2)
            .overlay(Rectangle().stroke(selected ? color : PW.line, lineWidth: 1))
    }

    private func logRow(time: String, color: Color, msg: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(time)
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverInk)
                .tracking(1.2)
            Text(msg)
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(color)
                .tracking(0.8)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("NO ACTIVE RACE SESSION. START A SESSION ON THE SERVER TO SEE LIVE TIMING.")
                .font(PW.FontStyle.mono(11, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Post to wall

    private func postToParent() async {
        guard let base = mc.attachedMCURL, let state = viewModel.liveState else { return }
        posting = true
        defer { posting = false }
        var req = URLRequest(url: base.appendingPathComponent("api/postings"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mc.authorize(&req)
        let body: [String: Any] = [
            "track_id":      state.track.id,
            "track_name":    state.track.name,
            "vehicle_class": "Mixed",
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
}
