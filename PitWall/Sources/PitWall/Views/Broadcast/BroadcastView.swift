import SwiftUI

struct BroadcastView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(AuthManager.self) private var authManager

    @State private var selectedMode: LiveState.BroadcastInfo.BroadcastMode = .auto
    @State private var selectedScene: String = "Main Feed"
    @State private var selectedCamera: CameraType = .onboard
    @State private var isSaving = false
    @State private var saveError: String?

    private var api: PitWallAPI {
        PitWallAPI(authManager: authManager)
    }

    private let availableScenes = [
        "Main Feed", "Onboard", "Trackside North", "Trackside South",
        "Pit Lane", "Start/Finish", "Sector 1", "Sector 2", "Sector 3"
    ]

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left column — controls
                ScrollView {
                    VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                        directorModeSection
                        scenePickerSection
                        cameraTypeSection
                        if let error = saveError {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(PW.guards)
                        }
                    }
                    .padding(PW.cardPadding)
                }
                .frame(width: 280)
                .background(PW.panel)

                Divider().background(PW.line)

                // Right column — interest scores + events
                ScrollView {
                    VStack(alignment: .leading, spacing: PW.sectionSpacing) {
                        interestScoresSection
                        recentEventsSection
                        displayOutputSection
                    }
                    .padding(PW.cardPadding)
                }
            }
        }
        .navigationTitle("Broadcast")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if let broadcast = viewModel.liveState?.broadcast {
                selectedMode = broadcast.mode
                if let scene = broadcast.scene {
                    selectedScene = scene
                }
            }
        }
    }

    // MARK: - Director mode

    private var directorModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DIRECTOR MODE")

            HStack(spacing: 0) {
                ForEach([
                    LiveState.BroadcastInfo.BroadcastMode.auto,
                    .manual,
                    .off
                ], id: \.self) { mode in
                    Button {
                        selectedMode = mode
                        Task { await saveMode(mode) }
                    } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(selectedMode == mode ? PW.silver : PW.silverDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedMode == mode ? PW.guards : PW.panel2)
                    }
                }
            }
            .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
        }
    }

    // MARK: - Scene picker

    private var scenePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SCENE")

            VStack(spacing: 0) {
                ForEach(availableScenes, id: \.self) { scene in
                    Button {
                        selectedScene = scene
                        Task { await saveScene(scene) }
                    } label: {
                        HStack {
                            if selectedScene == scene {
                                Rectangle()
                                    .fill(PW.guards)
                                    .frame(width: 3)
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 3)
                            }

                            Text(scene)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(selectedScene == scene ? PW.silver : PW.silverMid)
                                .padding(.leading, 12)
                                .padding(.vertical, 10)

                            Spacer()

                            if selectedScene == scene {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PW.guards)
                                    .padding(.trailing, 12)
                            }
                        }
                        .background(selectedScene == scene ? PW.guards.opacity(0.05) : PW.panel2)
                    }
                    Divider().background(PW.line)
                }
            }
        }
    }

    // MARK: - Camera type grid

    private var cameraTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("CAMERA TYPE")

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(CameraType.allCases, id: \.self) { cam in
                    Button {
                        selectedCamera = cam
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: cam.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(selectedCamera == cam ? PW.guards : PW.silverDim)
                            Text(cam.label)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(selectedCamera == cam ? PW.silver : PW.silverDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedCamera == cam ? PW.guards.opacity(0.1) : PW.panel2)
                        .overlay(
                            Rectangle()
                                .stroke(selectedCamera == cam ? PW.guards : PW.line, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Interest scores

    private var interestScoresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("INTEREST SCORES")

            let rigs = viewModel.liveState?.rigs.filter { $0.status == .occupied } ?? []

            if rigs.isEmpty {
                Text("No active drivers")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(rigs) { rig in
                        interestBar(rig: rig)
                    }
                }
            }
        }
    }

    private func interestBar(rig: LiveRig) -> some View {
        // Interest score is synthetic — based on position and lap count
        let score: Double = {
            guard let pos = rig.position, let lap = rig.currentLap else { return 0.3 }
            let posScore = max(0, 1.0 - (Double(pos - 1) * 0.15))
            let lapScore = min(1.0, Double(lap) / 15.0)
            return (posScore * 0.7 + lapScore * 0.3)
        }()

        let isFocused = viewModel.liveState?.broadcast.focus.map { $0 == (rig.position ?? -1) } ?? false

        return HStack(spacing: 10) {
            Button {
                Task { await setFocus(rig: rig) }
            } label: {
                HStack(spacing: 6) {
                    if isFocused {
                        Circle()
                            .fill(PW.guards)
                            .frame(width: 6, height: 6)
                    }
                    Text((rig.driverName ?? rig.label).uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isFocused ? PW.silver : PW.silverMid)
                        .lineLimit(1)
                }
                .frame(width: 130, alignment: .leading)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(PW.panel2)
                    Rectangle()
                        .fill(isFocused ? PW.guards : PW.info)
                        .frame(width: geo.size.width * score)
                }
            }
            .frame(height: 16)

            Text(String(format: "%.0f%%", score * 100))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(PW.silverDim)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Recent events feed

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RECENT EVENTS")

            let events = syntheticEvents
            if events.isEmpty {
                Text("No events yet")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(PW.silverDim)
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        eventRow(event)
                        Divider().background(PW.line)
                    }
                }
            }
        }
    }

    private var syntheticEvents: [BroadcastEvent] {
        guard let rigs = viewModel.liveState?.rigs else { return [] }
        var events: [BroadcastEvent] = []

        for rig in rigs where rig.status == .occupied {
            if let bestLap = rig.bestLapMs, let lastLap = rig.lastLapMs, lastLap == bestLap {
                events.append(BroadcastEvent(
                    id: "pb-\(rig.id)",
                    type: .personalBest,
                    driver: rig.driverName ?? rig.label,
                    detail: formatLap(bestLap)
                ))
            }
            if let pit = rig.pitStatus, pit == .inPit {
                events.append(BroadcastEvent(
                    id: "pit-\(rig.id)",
                    type: .pit,
                    driver: rig.driverName ?? rig.label,
                    detail: "In pit lane"
                ))
            }
        }

        return events
    }

    private func eventRow(_ event: BroadcastEvent) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(event.type.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(event.type.color)
                Text(event.driver)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PW.silver)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PW.silverDim)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Display output status

    private var displayOutputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DISPLAY OUTPUTS")

            VStack(spacing: 4) {
                ForEach(["TV1", "TV2", "PITLANE"], id: \.self) { output in
                    HStack {
                        Text(output)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(PW.silver)
                            .frame(width: 70, alignment: .leading)

                        Text(selectedMode == .off ? "OFF" : selectedScene.uppercased())
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(selectedMode == .off ? PW.silverDim : PW.info)

                        Spacer()

                        Text(selectedMode.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(statusColor(selectedMode))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor(selectedMode).opacity(0.15))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PW.panel2)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(PW.silverDim)
    }

    private func statusColor(_ mode: LiveState.BroadcastInfo.BroadcastMode) -> Color {
        switch mode {
        case .auto: return PW.ok
        case .manual: return PW.warn
        case .off: return PW.silverDim
        }
    }

    private func saveMode(_ mode: LiveState.BroadcastInfo.BroadcastMode) async {
        // API call to update broadcast mode would go here
        // Endpoint not yet documented — fire-and-forget placeholder
        _ = mode
    }

    private func saveScene(_ scene: String) async {
        _ = scene
    }

    private func setFocus(rig: LiveRig) async {
        _ = rig
    }

    private func formatLap(_ ms: Int) -> String {
        let m = ms / 60_000
        let s = Double(ms % 60_000) / 1000.0
        return String(format: "%d:%06.3f", m, s)
    }
}

// MARK: - Camera type enum

enum CameraType: String, CaseIterable {
    case onboard
    case chase
    case bumper
    case roof
    case trackside
    case free

    var label: String { rawValue.uppercased() }

    var icon: String {
        switch self {
        case .onboard: return "camera.fill"
        case .chase: return "car.rear.fill"
        case .bumper: return "car.fill"
        case .roof: return "arrow.up.square.fill"
        case .trackside: return "camera.on.rectangle.fill"
        case .free: return "move.3d"
        }
    }
}

// MARK: - Broadcast event model

struct BroadcastEvent: Identifiable {
    let id: String
    let type: EventType
    let driver: String
    let detail: String

    enum EventType {
        case overtake, personalBest, incident, pit

        var label: String {
            switch self {
            case .overtake: return "Overtake"
            case .personalBest: return "Personal Best"
            case .incident: return "Incident"
            case .pit: return "Pit Stop"
            }
        }

        var color: Color {
            switch self {
            case .overtake: return PW.guards
            case .personalBest: return PW.ok
            case .incident: return PW.warn
            case .pit: return PW.info
            }
        }
    }
}
