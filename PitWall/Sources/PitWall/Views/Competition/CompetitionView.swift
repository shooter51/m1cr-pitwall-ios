import SwiftUI

struct CompetitionView: View {
    @Environment(DashboardViewModel.self) private var dashboardVM
    @Environment(MCClient.self) private var mc
    @State private var competitionVM: CompetitionViewModel?
    @State private var showCreateForm = false

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "03 · OPERATIONS",
                title: "Competition"
            ) {
                Text("FORMAT · FASTEST LAP")
                PWTopBarDivider()
                Text("CLASS · GT3")
                PWTopBarDivider()
                Text("ENTRIES · 23")
            } actions: {
                Button("END COMP") {}
                    .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                Button {
                    showCreateForm = true
                } label: {
                    Text("+ NEW")
                }
                .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            }

            // Live banner
            if let active = dashboardVM.liveState?.competition {
                liveBanner(competition: active)
            }

            HStack(spacing: 0) {
                // Standings table
                standingsSection

                Rectangle().fill(PW.line).frame(width: 1)

                // Calendar aside
                calendarAside
                    .frame(width: 280)
            }
            .frame(maxHeight: .infinity)
        }
        .background(PW.carbon)
        .sheet(isPresented: $showCreateForm) {
            if let vm = competitionVM {
                CreateCompetitionSheet(vm: vm)
            }
        }
        .task {
            let vm = CompetitionViewModel(mc: mc)
            competitionVM = vm
            await vm.loadCompetitions()
        }
        .alert("Competition Error", isPresented: Binding(
            get: { competitionVM?.error != nil },
            set: { if !$0 { competitionVM?.error = nil } }
        )) {
            Button("OK", role: .cancel) { competitionVM?.error = nil }
        } message: {
            Text(competitionVM?.error ?? "")
        }
    }

    // MARK: - Live banner

    private func liveBanner(competition: Competition) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 24) {
                HStack(spacing: 10) {
                    StatusChip(.live)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("// FRIDAY · 19:00 – 23:00")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(2.0)
                        Text(competition.name.uppercased())
                            .font(PW.FontStyle.title(30))
                            .foregroundColor(PW.silver)
                            .tracking(-0.6)
                    }
                }

                HStack(spacing: 18) {
                    telBlock(label: "WINDOW LEFT", value: "03:14:22", color: PW.guardsBright)
                    telBlock(label: "ENTRIES", value: "23", color: PW.silver)
                    telBlock(label: "BEST LAP", value: "1:28.432", color: PW.ok)
                }

                Rectangle().fill(PW.line).frame(width: 1, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PRIZE")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.0)
                    if let prize = competition.prizeDescription {
                        Text(prize.uppercased())
                            .font(PW.FontStyle.title(22))
                            .foregroundColor(PW.warn)
                            .tracking(-0.22)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(PW.panel)
            .overlay(alignment: .leading) {
                Rectangle().fill(PW.guards).frame(width: 3)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(PW.line).frame(height: 1)
            }
            .clipped()

            CornerStripes(size: 80)
                .offset(x: 20, y: -20)
                .allowsHitTesting(false)
        }
    }

    private func telBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(2.0)
            Text(value)
                .font(PW.FontStyle.telemetry(20))
                .foregroundColor(color)
        }
    }

    // MARK: - Standings

    private var standingsSection: some View {
        VStack(spacing: 0) {
            // Column header
            HStack(spacing: 0) {
                timingHeader("POS",      w: 48)
                timingHeader("DRIVER",   flex: true)
                timingHeader("BEST LAP", w: 120, trailing: true)
                timingHeader("GAP",      w: 110, trailing: true)
                timingHeader("LAPS",     w: 60, trailing: true)
            }
            .padding(.horizontal, 22)
            .frame(height: 36)
            .background(PW.panel2)
            .overlay(alignment: .bottom) {
                Rectangle().fill(PW.line).frame(height: 1)
            }

            let occupied = dashboardVM.liveState?.rigs
                .filter { $0.status == .occupied }
                .sorted { ($0.position ?? 999) < ($1.position ?? 999) } ?? []

            if occupied.isEmpty {
                emptyStandings
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(occupied.enumerated()), id: \.element.id) { idx, rig in
                            standingsRow(rig: rig, idx: idx)
                            Rectangle().fill(PW.line).frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStandings: some View {
        VStack {
            Spacer()
            Text("NO DRIVERS ON TRACK")
                .font(PW.FontStyle.mono(11, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func standingsRow(rig: LiveRig, idx: Int) -> some View {
        let isLead = idx == 0
        let leaderBest = dashboardVM.liveState?.rigs
            .filter { $0.status == .occupied }
            .sorted { ($0.position ?? 999) < ($1.position ?? 999) }
            .first?.bestLapMs
        let gap = (isLead || leaderBest == nil) ? nil : rig.bestLapMs.map { $0 - (leaderBest ?? 0) }

        return HStack(spacing: 0) {
            // POS
            HStack(spacing: 0) {
                let pos = rig.position ?? (idx + 1)
                Text("P\(pos)")
                    .font(PW.FontStyle.mono(12, weight: .bold))
                    .foregroundColor(isLead ? .white : PW.silver)
                    .tracking(0.4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isLead ? PW.guards : (idx < 3 ? PW.panel3 : Color.clear))
            }
            .frame(width: 48, alignment: .leading)

            // DRIVER
            Text((rig.driverName ?? rig.label).uppercased())
                .font(PW.FontStyle.mono(13, weight: .semibold))
                .foregroundColor(PW.silver)
                .tracking(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // BEST LAP
            Text(formatLap(rig.bestLapMs))
                .font(PW.FontStyle.mono(14, weight: .bold))
                .foregroundColor(isLead ? PW.guardsBright : PW.ok)
                .frame(width: 120, alignment: .trailing)

            // GAP
            Text(isLead ? "— LEADER" : formatGap(gap))
                .font(PW.FontStyle.mono(12, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .frame(width: 110, alignment: .trailing)

            // LAPS
            Text("\(rig.currentLap ?? 0)")
                .font(PW.FontStyle.mono(12, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .frame(height: 40)
        .background(isLead ? PW.guardsBright.opacity(0.07) : (idx % 2 != 0 ? PW.carbon2 : Color.clear))
        .overlay(alignment: .leading) {
            if isLead { Rectangle().fill(PW.guards).frame(width: 3) }
        }
    }

    @ViewBuilder
    private func timingHeader(_ text: String, w: CGFloat? = nil,
                               flex: Bool = false, trailing: Bool = false) -> some View {
        let aligned: Alignment = trailing ? .trailing : .leading
        let label = Text(text)
            .font(PW.FontStyle.mono(9, weight: .semibold))
            .foregroundColor(PW.silverDim)
            .tracking(2.2)
        if flex {
            label.frame(maxWidth: .infinity, alignment: aligned)
        } else if let w {
            label.frame(width: w, alignment: aligned)
        } else {
            label
        }
    }

    // MARK: - Calendar aside

    private var calendarAside: some View {
        let entries: [(st: String, name: String, when: String, note: String)] = [
            ("COMPLETED", "Brunch Time Attack", "11:00 – 13:00", "D. KIM 1:29.001"),
            ("COMPLETED", "Afternoon Sprint", "14:00 – 17:00", "F. OKONKWO 1:28.014"),
            ("LIVE", "Friday Night Cup", "19:00 – 23:00", "— NAVARRO P1"),
            ("SCHEDULED", "Saturday GT4 Endurance", "SAT 10:00", "0 / 32 entries"),
        ]

        return VStack(alignment: .leading, spacing: 14) {
            Text("// TODAY'S CALENDAR")
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundColor(PW.silverDim)
                .tracking(2.2)

            VStack(spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    calendarEntry(entry.st, name: entry.name, when: entry.when, note: entry.note)
                }
            }

            Spacer()
        }
        .padding(18)
        .background(PW.panel)
    }

    private func calendarEntry(_ status: String, name: String, when: String, note: String) -> some View {
        let accentColor: Color = status == "LIVE" ? PW.guards : status == "COMPLETED" ? PW.silverInk : PW.info
        let statusColor: Color = status == "LIVE" ? PW.guardsBright : status == "COMPLETED" ? PW.silverDim : PW.info

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(status)
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(statusColor)
                    .tracking(2.0)
                Spacer()
                Text(when)
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
            }
            Text(name)
                .font(PW.FontStyle.body(13))
                .foregroundColor(PW.silver)
                .fontWeight(.semibold)
            Text(note.uppercased())
                .font(PW.FontStyle.mono(9, weight: .semibold))
                .foregroundColor(PW.silverMid)
                .tracking(1.4)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(PW.carbon2)
        .overlay(alignment: .leading) {
            Rectangle().fill(accentColor).frame(width: 2)
        }
    }

    // MARK: - Formatting

    private func formatLap(_ ms: Int?) -> String { LapTimeFormatter.format(ms) }
    private func formatGap(_ ms: Int?) -> String {
        guard let ms else { return "—" }
        if ms == 0 { return "LEADER" }
        return String(format: "+%.3fs", Double(ms) / 1000.0)
    }
}

// MARK: - Keep existing helper views from original file

struct ActiveCompetitionBanner: View {
    let competition: Competition
    var body: some View {
        HStack(spacing: 16) {
            Rectangle().fill(PW.guards).frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    StatusChip(.live, compact: true)
                    Text(competition.name.uppercased())
                        .font(PW.FontStyle.title(14))
                        .foregroundColor(PW.silver)
                        .lineLimit(1)
                }
                HStack(spacing: 12) {
                    Text(competition.type.displayName.uppercased())
                        .font(PW.FontStyle.mono(10, weight: .semibold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.6)
                    Text(competition.trackName.uppercased())
                        .font(PW.FontStyle.mono(10, weight: .semibold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.6)
                }
            }
            Spacer()
            if let prize = competition.prizeDescription {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PRIZE")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.2)
                    Text(prize)
                        .font(PW.FontStyle.body(12))
                        .foregroundColor(PW.warn)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.trailing, PW.cardPadding)
        .background(PW.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PW.guards.opacity(0.4)).frame(height: 1)
        }
    }
}

struct CompetitionRow: View {
    let competition: Competition
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(competition.name)
                    .font(PW.FontStyle.body(13))
                    .foregroundColor(PW.silver)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(competition.type.displayName)
                        .font(PW.FontStyle.mono(10, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.6)
                    Text(competition.trackName)
                        .font(PW.FontStyle.mono(10, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.6)
                }
            }
            Spacer()
            StatusChip(mapCompStatus(competition.status), compact: true)
        }
        .padding(.horizontal, PW.cardPadding)
        .padding(.vertical, 10)
        .background(PW.panel)
    }

    private func mapCompStatus(_ s: Competition.CompetitionStatus) -> StatusChip.Status {
        switch s {
        case .active: return .live
        case .scheduled: return .available
        case .completed: return .ended
        case .cancelled: return .offline
        }
    }
}

// MARK: - Create Competition Sheet

struct CreateCompetitionSheet: View {
    let vm: CompetitionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type = Competition.CompetitionType.fastestLap
    @State private var trackId = ""
    @State private var vehicleClass = "GT3"
    @State private var prizeDescription = ""
    @State private var maxParticipantsText = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ZStack {
                PW.carbon.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                        formField(label: "NAME", placeholder: "Friday Night Cup") {
                            TextField("", text: $name)
                                .textFieldStyle(PWTextFieldStyle())
                        }
                        formField(label: "TYPE") {
                            Picker("", selection: $type) {
                                ForEach(Competition.CompetitionType.allCases, id: \.self) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorScheme(.dark)
                        }
                        formField(label: "TRACK NAME", placeholder: "Laguna Seca") {
                            TextField("", text: $trackId).textFieldStyle(PWTextFieldStyle())
                        }
                        formField(label: "VEHICLE CLASS", placeholder: "GT3") {
                            TextField("", text: $vehicleClass).textFieldStyle(PWTextFieldStyle())
                        }
                        formField(label: "PRIZE DESCRIPTION", placeholder: "£50 voucher (optional)") {
                            TextField("", text: $prizeDescription).textFieldStyle(PWTextFieldStyle())
                        }
                        formField(label: "MAX PARTICIPANTS", placeholder: "10 (optional)") {
                            TextField("", text: $maxParticipantsText)
                                .textFieldStyle(PWTextFieldStyle())
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }
                        Button(action: submit) {
                            HStack {
                                if isCreating {
                                    ProgressView().scaleEffect(0.8).tint(PW.silver)
                                } else {
                                    Text("CREATE COMPETITION")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.isEmpty || isCreating)
                    }
                    .padding(PW.cardPadding)
                }
            }
            .navigationTitle("New Competition")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(PW.silverMid)
                }
            }
        }
    }

    @ViewBuilder
    private func formField<Content: View>(label: String, placeholder: String = "",
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(PW.FontStyle.mono(10, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(2.0)
            content()
        }
    }

    private func submit() {
        guard !name.isEmpty else { return }
        isCreating = true
        let params = CreateCompetitionParams(
            name: name, type: type, trackId: trackId,
            vehicleClass: vehicleClass,
            maxParticipants: Int(maxParticipantsText),
            prizeDescription: prizeDescription.isEmpty ? nil : prizeDescription
        )
        Task {
            defer { isCreating = false }
            let success = await vm.create(params: params)
            if success { dismiss() }
        }
    }
}

// MARK: - Text Field Style
struct PWTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(PW.FontStyle.mono(14, weight: .semibold))
            .foregroundColor(PW.silver)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PW.panel2)
            .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
    }
}

// MARK: - Competition type helpers
extension Competition.CompetitionType: CaseIterable {
    public static var allCases: [Competition.CompetitionType] {
        [.fastestLap, .race, .endurance, .timeAttack]
    }
    var displayName: String {
        switch self {
        case .fastestLap: return "Fastest Lap"
        case .race: return "Race"
        case .endurance: return "Endurance"
        case .timeAttack: return "Time Attack"
        }
    }
}
