import SwiftUI

struct BroadcastView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @Environment(MCClient.self) private var mc

    @State private var selectedMode: LiveState.BroadcastInfo.BroadcastMode = .auto
    @State private var selectedScene: String = "Main Feed"
    @State private var selectedCamera: CameraType = .chase
    @State private var saveError: String?
    @State private var api: PitWallAPI?

    private func resolvedAPI() -> PitWallAPI {
        if let api { return api }
        let newAPI = PitWallAPI(mc: mc)
        api = newAPI
        return newAPI
    }

    private let availableScenes = [
        "Main Feed", "Onboard P1", "Trackside North", "Trackside South",
        "Pit Lane", "Start / Finish", "Sector 1", "Sector 2", "Sector 3"
    ]

    private let sceneKeybinds = ["⌘1","⌘2","⌘3","⌘4","⌘5","⌘6","⌘7","⌘8","⌘9"]

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "04 · MEDIA",
                title: "Broadcast"
            ) {
                Text("SCENE · MAIN FEED")
                PWTopBarDivider()
                Text("NDI · UP 240MBPS")
                PWTopBarDivider()
                Text("OBS · CONNECTED")
            } actions: {
                Button("GO LIVE →") {}
                    .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            }

            // Preview-only warning stripe
            HStack(spacing: 14) {
                Rectangle().fill(PW.warn).frame(width: 7, height: 7)
                Text("PREVIEW MODE · CHANGES NOT SENT TO PRODUCTION")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.warn)
                    .tracking(2.2)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 6)
            .background(PW.warn.opacity(0.08))
            .overlay(alignment: .bottom) {
                Rectangle().fill(PW.warn.opacity(0.32)).frame(height: 1)
            }

            HStack(spacing: 0) {
                leftControls
                Rectangle().fill(PW.line).frame(width: 1)
                centerMonitor
                Rectangle().fill(PW.line).frame(width: 1)
                rightStack
            }
            .frame(maxHeight: .infinity)
        }
        .background(PW.carbon)
        .onAppear {
            if let broadcast = viewModel.liveState?.broadcast {
                selectedMode = broadcast.mode
                if let scene = broadcast.scene { selectedScene = scene }
            }
        }
    }

    // MARK: - Left: Director controls

    private var leftControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Director mode segmented
            VStack(alignment: .leading, spacing: 8) {
                Text("// DIRECTOR MODE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                HStack(spacing: 0) {
                    ForEach(Array([
                        LiveState.BroadcastInfo.BroadcastMode.auto,
                        .manual, .off
                    ].enumerated()), id: \.offset) { idx, mode in
                        Button {
                            selectedMode = mode
                            Task { await saveMode(mode) }
                        } label: {
                            Text(mode.rawValue.uppercased())
                                .font(PW.FontStyle.mono(11, weight: .bold))
                                .foregroundColor(selectedMode == mode ? .white : PW.silverMid)
                                .tracking(1.6)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(selectedMode == mode ? PW.guards : PW.carbon2)
                        }
                        if idx < 2 {
                            Rectangle().fill(PW.lineStrong).frame(width: 1)
                        }
                    }
                }
                .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
            }
            .padding(16)
            .padding(.bottom, 6)

            Rectangle().fill(PW.line).frame(height: 1)

            // Scene list
            VStack(alignment: .leading, spacing: 0) {
                Text("// SCENE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                VStack(spacing: 1) {
                    ForEach(Array(availableScenes.enumerated()), id: \.offset) { idx, scene in
                        let sel = selectedScene == scene
                        Button {
                            selectedScene = scene
                            Task { await saveScene(scene) }
                        } label: {
                            HStack {
                                Text(scene)
                                    .font(PW.FontStyle.mono(12, weight: sel ? .semibold : .medium))
                                    .foregroundColor(sel ? PW.silver : PW.silverMid)
                                Spacer()
                                Text(sceneKeybinds[safe: idx] ?? "")
                                    .font(PW.FontStyle.mono(9, weight: .bold))
                                    .foregroundColor(sel ? PW.guardsBright : PW.silverInk)
                                    .tracking(1.6)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(sel ? PW.guardsBright.opacity(0.08) : PW.carbon2)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(sel ? PW.guards : Color.clear)
                                    .frame(width: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            Rectangle().fill(PW.line).frame(height: 1)

            // Camera type grid
            VStack(alignment: .leading, spacing: 8) {
                Text("// CAMERA TYPE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                let cams = ["ONBOARD","CHASE","TRACKSIDE","BUMPER","HOOD","HELI"]
                let camTypes: [CameraType] = [.onboard, .chase, .trackside, .bumper, .roof, .free]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(Array(cams.enumerated()), id: \.offset) { idx, name in
                        let sel = selectedCamera == camTypes[safe: idx] ?? .onboard
                        Button {
                            selectedCamera = camTypes[safe: idx] ?? .onboard
                        } label: {
                            Text(name)
                                .font(PW.FontStyle.mono(10, weight: .bold))
                                .foregroundColor(sel ? .white : PW.silverMid)
                                .tracking(1.4)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(sel ? PW.guards : PW.carbon2)
                                .overlay(Rectangle().stroke(sel ? PW.guards : PW.lineStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(PW.panel)
    }

    // MARK: - Center: Program monitor

    private var centerMonitor: some View {
        VStack(spacing: 12) {
            // Program monitor
            ZStack(alignment: .topLeading) {
                // Black background with radial washes
                ZStack {
                    Color.black
                    RadialGradient(
                        gradient: Gradient(colors: [PW.guards.opacity(0.18), Color.clear]),
                        center: UnitPoint(x: 0.3, y: 0.6),
                        startRadius: 0, endRadius: 200
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [PW.info.opacity(0.14), Color.clear]),
                        center: UnitPoint(x: 0.7, y: 0.3),
                        startRadius: 0, endRadius: 200
                    )
                    // Track silhouette placeholder
                    Rectangle()
                        .fill(PW.silverMid.opacity(0.03))
                }
                .clipped()

                // TL: LIVE chip + scene
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.white).frame(width: 6, height: 6)
                        Text("LIVE · PROGRAM")
                            .font(PW.FontStyle.mono(10, weight: .bold))
                            .foregroundColor(.white)
                            .tracking(1.8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(PW.guards)

                    Text("CHASE · P1 NAVARRO")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silver2)
                        .tracking(1.8)
                }
                .padding(.top, 14)
                .padding(.leading, 16)

                // TR: clock
                Text("15:42:18 · L12 / 20")
                    .font(PW.FontStyle.mono(11, weight: .semibold))
                    .foregroundColor(PW.silver)
                    .tracking(1.2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 14)
                    .padding(.trailing, 16)

                // Lower-third overlay
                HStack(spacing: 0) {
                    Text("P1")
                        .font(PW.FontStyle.card(32))
                        .foregroundColor(.white)
                        .tracking(-0.64)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(PW.guards)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("A. NAVARRO")
                            .font(PW.FontStyle.card(26))
                            .foregroundColor(PW.silver)
                            .tracking(-0.52)
                        Text("RIG 01 · GT3 · 1:28.432")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silver2)
                            .tracking(2.0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(PW.guards).frame(width: 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, 16)
                .padding(.leading, 16)

                // BR: interest score
                VStack(alignment: .trailing, spacing: 4) {
                    Text("AI · INTEREST")
                        .font(PW.FontStyle.mono(8, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.0)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("94")
                            .font(PW.FontStyle.telemetry(28))
                            .foregroundColor(PW.guardsBright)
                        Text("/ 100")
                            .font(PW.FontStyle.mono(11, weight: .medium))
                            .foregroundColor(PW.silverDim)
                    }
                    Text("HOT LAP IN PROGRESS")
                        .font(PW.FontStyle.mono(8, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.6)
                }
                .padding(12)
                .background(Color.black.opacity(0.72))
                .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, 16)
                .padding(.trailing, 16)
            }
            .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

            // Preview strip (4 tiles)
            HStack(spacing: 8) {
                ForEach(previewTiles, id: \.label) { tile in
                    ZStack(alignment: .topLeading) {
                        LinearGradient(
                            gradient: Gradient(colors: [PW.panel2, PW.carbon2]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(Rectangle().stroke(tile.isNext ? PW.guards : PW.line, lineWidth: 1))

                        if let tag = tile.tag {
                            Text(tag)
                                .font(PW.FontStyle.mono(8, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(1.8)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(tile.tagColor ?? PW.guards)
                        }

                        VStack(alignment: .leading) {
                            Spacer()
                            HStack {
                                Text(tile.label)
                                    .font(PW.FontStyle.mono(10, weight: .semibold))
                                    .foregroundColor(PW.silver)
                                    .tracking(1.6)
                                Spacer()
                                Text("\(tile.score)")
                                    .font(PW.FontStyle.mono(9, weight: .semibold))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(1.6)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 78)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 78)
            .padding(.bottom, 0)
        }
        .padding(16)
        .background(PW.carbon)
    }

    private struct PreviewTile {
        let label: String
        let tag: String?
        let tagColor: Color?
        let score: Int
        var isNext: Bool { tag == "NEXT" }
    }

    private var previewTiles: [PreviewTile] {[
        .init(label: "ONBOARD · P1", tag: "NEXT", tagColor: PW.guards, score: 94),
        .init(label: "TRACKSIDE N", tag: nil, tagColor: nil, score: 72),
        .init(label: "CHASE · P3/4", tag: "BATTLE", tagColor: PW.warn, score: 88),
        .init(label: "PIT LANE", tag: nil, tagColor: nil, score: 41),
    ]}

    // MARK: - Right: interest + events

    private var rightStack: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Interest stack
            VStack(alignment: .leading, spacing: 8) {
                Text("// INTEREST · LIVE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                let driven = (viewModel.liveState?.rigs ?? [])
                    .filter { $0.status == .occupied && $0.position != nil }
                    .sorted { ($0.position ?? 999) < ($1.position ?? 999) }
                let scores = [94, 88, 81, 67, 54, 41, 33]

                VStack(spacing: 5) {
                    ForEach(Array(driven.prefix(7).enumerated()), id: \.element.id) { idx, rig in
                        let score = scores[safe: idx] ?? 30
                        HStack(spacing: 8) {
                            Text("P\(rig.position ?? (idx + 1))")
                                .font(PW.FontStyle.mono(10, weight: .bold))
                                .foregroundColor(idx == 0 ? .white : PW.silverMid)
                                .tracking(0.4)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(idx == 0 ? PW.guards : PW.panel3)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text((rig.driverName ?? rig.label))
                                    .font(PW.FontStyle.mono(10, weight: .semibold))
                                    .foregroundColor(PW.silver)
                                    .tracking(0.6)
                                    .lineLimit(1)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Rectangle().fill(PW.panel3).frame(height: 3)
                                        Rectangle()
                                            .fill(idx == 0 ? PW.guards : idx < 3 ? PW.guardsBright : PW.silverMid)
                                            .frame(width: geo.size.width * Double(score) / 100.0, height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }

                            Text("\(score)")
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(idx == 0 ? PW.guardsBright : PW.silverMid)
                                .tracking(0.4)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }

            Rectangle().fill(PW.line).frame(height: 1)

            // Recent events
            VStack(alignment: .leading, spacing: 8) {
                Text("// RECENT EVENTS")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                VStack(spacing: 9) {
                    ForEach(recentEvents, id: \.kind) { ev in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(ev.kind)
                                    .font(PW.FontStyle.mono(9, weight: .bold))
                                    .foregroundColor(ev.color)
                                    .tracking(2.2)
                                Spacer()
                                Text("\(ev.ago) AGO")
                                    .font(PW.FontStyle.mono(9, weight: .semibold))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(1.6)
                            }
                            Text(ev.who)
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(PW.silver)
                                .tracking(0.6)
                            Text(ev.detail)
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.silverDim)
                                .tracking(1.4)
                        }
                        .padding(8)
                        .background(PW.carbon2)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(ev.color).frame(width: 2)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 260)
        .background(PW.panel)
    }

    private struct RecentEvent {
        let kind: String; let color: Color; let who: String
        let detail: String; let ago: String
    }

    private var recentEvents: [RecentEvent] {[
        .init(kind: "OVERTAKE", color: PW.guardsBright, who: "KELLER P3 → P2",   detail: "CORKSCREW",    ago: "0:08"),
        .init(kind: "PB",       color: PW.ok,           who: "NAVARRO",           detail: "1:28.432",     ago: "0:22"),
        .init(kind: "OFF",      color: PW.warn,         who: "MENDOZA · T5",      detail: "CONTINUES",    ago: "0:34"),
        .init(kind: "OVERTAKE", color: PW.guardsBright, who: "PETERSEN P5→P4",    detail: "ANDRETTI",     ago: "0:58"),
        .init(kind: "PIT IN",   color: PW.silverMid,    who: "ROSSI",             detail: "TIRES + FUEL", ago: "1:11"),
    ]}

    // MARK: - Actions

    private func saveMode(_ mode: LiveState.BroadcastInfo.BroadcastMode) async { _ = mode }
    private func saveScene(_ scene: String) async { _ = scene }

    private func formatLap(_ ms: Int) -> String { LapTimeFormatter.format(ms) }
}

// MARK: - Camera type enum

enum CameraType: String, CaseIterable {
    case onboard, chase, bumper, roof, trackside, free
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
    let id: String; let type: EventType; let driver: String; let detail: String
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

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
