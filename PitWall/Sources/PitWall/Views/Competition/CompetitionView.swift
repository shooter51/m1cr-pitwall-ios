import SwiftUI

struct CompetitionView: View {
    @Environment(DashboardViewModel.self) private var dashboardVM
    @Environment(MCClient.self) private var mc
    @State private var competitionVM: CompetitionViewModel?
    @State private var showCreateForm = false

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            VStack(spacing: 0) {
                // Active competition banner
                if let active = dashboardVM.liveState?.competition {
                    ActiveCompetitionBanner(competition: active)
                }

                // Standings table header
                standingsHeader

                // Main content
                if competitionVM?.isLoading == true {
                    Spacer()
                    ProgressView()
                        .tint(PW.guards)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Standings
                            standingsSection

                            Divider().background(PW.lineStrong)
                                .padding(.vertical, PW.sectionSpacing)

                            // Past competitions today
                            pastSection
                        }
                        .padding(.bottom, PW.sectionSpacing)
                    }
                    .refreshable { await competitionVM?.loadCompetitions() }
                }
            }
        }
        .navigationTitle("Competition")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateForm = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(PW.guards)
                }
            }
        }
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

    // MARK: - Standings section

    private var standingsHeader: some View {
        HStack {
            Text("STANDINGS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Spacer()
            if competitionVM?.isLoading == true {
                ProgressView().scaleEffect(0.7).tint(PW.silverDim)
            }
        }
        .padding(.horizontal, PW.cardPadding)
        .padding(.vertical, 10)
        .background(PW.panel2)
    }

    private var standingsSection: some View {
        VStack(spacing: 0) {
            // Column header
            HStack {
                Text("POS").frame(width: 36, alignment: .center)
                Text("DRIVER").frame(maxWidth: .infinity, alignment: .leading)
                Text("BEST LAP").frame(width: 90, alignment: .trailing)
                Text("GAP").frame(width: 80, alignment: .trailing)
                Text("LAPS").frame(width: 48, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(PW.silverDim)
            .padding(.horizontal, PW.cardPadding)
            .padding(.vertical, 8)
            .background(PW.panel)

            let occupied = dashboardVM.liveState?.rigs
                .filter { $0.status == .occupied }
                .sorted { ($0.position ?? 999) < ($1.position ?? 999) } ?? []

            if occupied.isEmpty {
                Text("No drivers on track. Standings will appear when drivers start racing.")
                    .font(.system(size: 13))
                    .foregroundStyle(PW.silverDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 24)
            } else {
                ForEach(occupied) { rig in
                    standingsRow(rig: rig, leaderBestMs: occupied.first?.bestLapMs)
                    Divider().background(PW.line)
                }
            }
        }
    }

    private func standingsRow(rig: LiveRig, leaderBestMs: Int?) -> some View {
        let pos = rig.position ?? 99
        let isLeader = pos == 1

        return HStack {
            Text("P\(pos)")
                .frame(width: 36, alignment: .center)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isLeader ? PW.guards : PW.silverMid)

            Text((rig.driverName ?? rig.label).uppercased())
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(PW.silver)
                .lineLimit(1)

            Text(formatLap(rig.bestLapMs))
                .frame(width: 90, alignment: .trailing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PW.ok)

            Text(formatGap(rig.gapToLeaderMs))
                .frame(width: 80, alignment: .trailing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PW.silverDim)

            Text(rig.currentLap.map { "\($0)" } ?? "—")
                .frame(width: 48, alignment: .trailing)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(PW.silverMid)
        }
        .padding(.horizontal, PW.cardPadding)
        .padding(.vertical, 8)
        .background(isLeader ? PW.guards.opacity(0.05) : Color.clear)
        .overlay(alignment: .leading) {
            if isLeader {
                Rectangle().fill(PW.guards).frame(width: 3)
            }
        }
    }

    // MARK: - Past competitions section

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TODAY'S COMPETITIONS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
                Spacer()
                Button("Refresh") {
                    Task { await competitionVM?.loadCompetitions() }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(PW.guards)
            }
            .padding(.horizontal, PW.cardPadding)
            .padding(.vertical, 10)
            .background(PW.panel2)

            let comps = competitionVM?.competitions ?? []
            if comps.isEmpty {
                Text("No competitions today")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(comps) { comp in
                    CompetitionRow(competition: comp)
                    Divider().background(PW.line)
                }
            }
        }
    }

    // MARK: - Formatting

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

// MARK: - Active Competition Banner

struct ActiveCompetitionBanner: View {
    let competition: Competition

    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(PW.guards)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(PW.guards)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PW.guards.opacity(0.15))

                    Text(competition.name.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PW.silver)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Text(competition.type.displayName.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PW.silverMid)

                    Text(competition.trackName.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PW.silverMid)

                    Text(competition.vehicleClass.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PW.info)
                }
            }

            Spacer()

            if let prize = competition.prizeDescription {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PRIZE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PW.silverDim)
                    Text(prize)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PW.warn)
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

// MARK: - Competition Row

struct CompetitionRow: View {
    let competition: Competition

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(competition.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PW.silver)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(competition.type.displayName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PW.silverDim)
                    Text(competition.trackName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PW.silverDim)
                }
            }

            Spacer()

            statusBadge(competition.status)
        }
        .padding(.horizontal, PW.cardPadding)
        .padding(.vertical, 10)
        .background(PW.panel)
    }

    private func statusBadge(_ status: Competition.CompetitionStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
    }

    private func statusColor(_ status: Competition.CompetitionStatus) -> Color {
        switch status {
        case .active: return PW.guards
        case .scheduled: return PW.info
        case .completed: return PW.ok
        case .cancelled: return PW.silverDim
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
                            TextField("", text: $trackId)
                                .textFieldStyle(PWTextFieldStyle())
                        }

                        formField(label: "VEHICLE CLASS", placeholder: "GT3") {
                            TextField("", text: $vehicleClass)
                                .textFieldStyle(PWTextFieldStyle())
                        }

                        formField(label: "PRIZE DESCRIPTION", placeholder: "£50 voucher (optional)") {
                            TextField("", text: $prizeDescription)
                                .textFieldStyle(PWTextFieldStyle())
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
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PW.silverMid)
                }
            }
        }
    }

    @ViewBuilder
    private func formField<Content: View>(
        label: String,
        placeholder: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            content()
        }
    }

    private func submit() {
        guard !name.isEmpty else { return }
        isCreating = true

        let params = CreateCompetitionParams(
            name: name,
            type: type,
            trackId: trackId,
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
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(PW.silver)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PW.panel2)
            .overlay(
                Rectangle()
                    .stroke(PW.lineStrong, lineWidth: 1)
            )
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
