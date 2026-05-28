import SwiftUI

struct ServerControlView: View {
    @Environment(DashboardViewModel.self) private var viewModel
    @State private var serverStatus: ServerStatus?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showConfirmStart = false
    @Environment(MCClient.self) private var mc
    @State private var api: PitWallAPI?

    private func resolvedAPI() -> PitWallAPI {
        if let api { return api }
        let newAPI = PitWallAPI(mc: mc)
        api = newAPI
        return newAPI
    }

    private var currentStatus: ServerStatus.EC2Status {
        serverStatus?.status ?? viewModel.serverStatus
    }

    private var isRunning: Bool { currentStatus == .running }

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "07 · SYSTEM",
                title: "Server Control"
            ) {
                Text("HOST · AWS EC2 · c6i.2xlarge")
                PWTopBarDivider()
                Text("REGION · us-west-2")
            } actions: {
                Button("REFRESH") { Task { await refreshStatus() } }
                    .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                Button("RESTART") {}
                    .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
                if currentStatus == .stopped {
                    Button("START SERVER") { showConfirmStart = true }
                        .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
                } else if currentStatus == .running {
                    Button("STOP SERVER") { showConfirmStart = true }
                        .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
                }
            }

            // Body: 1.4fr left | 1fr right
            GeometryReader { geo in
                let leftWidth = geo.size.width * (1.4 / 2.4)
                HStack(spacing: 0) {
                    leftColumn
                        .frame(width: leftWidth)
                    rightColumn
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(PW.carbon)
        .confirmationDialog(
            currentStatus == .stopped ? "Start Server?" : "Stop Server?",
            isPresented: $showConfirmStart,
            titleVisibility: .visible
        ) {
            if currentStatus == .stopped {
                Button("Start Server") { Task { await startServer() } }
            } else {
                Button("Stop Server", role: .destructive) {}
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(currentStatus == .stopped
                 ? "This will start the game server. It may take 1-2 minutes."
                 : "This will stop the game server. All active sessions will end.")
        }
        .task { await refreshStatus() }
    }

    // MARK: - Left column

    private var leftColumn: some View {
        ZStack(alignment: .bottomLeading) {
            // Mega background text
            Text("RUNNING")
                .font(PW.FontStyle.hero(320))
                .foregroundColor(Color.white.opacity(0.025))
                .tracking(-0.04 * 320)
                .lineLimit(1)
                .offset(x: -30, y: 80)
                .allowsHitTesting(false)
                .clipped()

            CornerStripes(size: 160)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 30, y: -30)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 26) {
                // Status hero
                VStack(alignment: .leading, spacing: 0) {
                    Text("// AMS2 DEDICATED SERVER")
                        .font(PW.FontStyle.mono(10, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.4)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(isRunning ? PW.ok : PW.silverDim)
                            .frame(width: 14, height: 14)
                        Text(currentStatus.displayName.uppercased())
                            .font(PW.FontStyle.hero(96))
                            .foregroundColor(PW.silver)
                            .tracking(-0.03 * 96)
                            .lineLimit(1)
                    }
                    .padding(.top, 12)

                    if isLoading {
                        ProgressView()
                            .tint(PW.guards)
                            .padding(.top, 10)
                    } else {
                        HStack(spacing: 14) {
                            Text("UPTIME · 03:42:18")
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(PW.silver2)
                                .tracking(1.8)
                            Rectangle().fill(PW.line).frame(width: 1, height: 14)
                            Text("7 / 10 CONNECTED")
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(PW.silver2)
                                .tracking(1.8)
                            Rectangle().fill(PW.line).frame(width: 1, height: 14)
                            Text("CPU 38% · MEM 9.2G")
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(PW.silver2)
                                .tracking(1.8)
                        }
                        .padding(.top, 10)
                    }

                    if let error {
                        Text(error)
                            .font(PW.FontStyle.mono(10, weight: .semibold))
                            .foregroundColor(PW.guards)
                            .padding(.top, 8)
                    }
                }

                // Network spec grid
                networkSpecGrid

                // Auto-idle notice
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("// AUTO-IDLE")
                            .font(PW.FontStyle.mono(9, weight: .bold))
                            .foregroundColor(PW.warn)
                            .tracking(2.2)
                        Text("Server stops automatically after 2 hours of zero connections. Cancel by starting a session.")
                            .font(PW.FontStyle.body(13))
                            .foregroundColor(PW.silver2)
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PW.carbon2)
                .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
                .overlay(alignment: .leading) {
                    Rectangle().fill(PW.warn).frame(width: 3)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(PW.carbon)
        .overlay(alignment: .trailing) {
            Rectangle().fill(PW.line).frame(width: 1)
        }
        .clipped()
    }

    private var networkSpecGrid: some View {
        let specs: [(label: String, value: String, dim: Bool)] = [
            ("PUBLIC IP",   serverStatus?.ip ?? "52.14.211.88",  false),
            ("LAN",         "192.168.1.42",                       false),
            ("PORT · GAME", "27015 / UDP",                        true),
            ("PORT · API",  "9000 / TCP",                         true),
            ("PORT · WSS",  "3001 / TCP",                         true),
            ("CREST2",      "8180 / TCP",                         true),
        ]

        return VStack(spacing: 0) {
            ForEach(Array(stride(from: 0, to: specs.count, by: 2)), id: \.self) { row in
                let isLastRow = row >= specs.count - 2
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { col in
                        let idx = row + col
                        if idx < specs.count {
                            let spec = specs[idx]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(spec.label)
                                    .font(PW.FontStyle.mono(9, weight: .semibold))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(2.2)
                                Text(spec.value)
                                    .font(PW.FontStyle.mono(14, weight: .bold))
                                    .foregroundColor(spec.dim ? PW.silver2 : PW.silver)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .trailing) {
                                if col == 0 {
                                    Rectangle().fill(PW.line).frame(width: 1)
                                }
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if !isLastRow {
                        Rectangle().fill(PW.line).frame(height: 1)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.7))
        .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Sparklines / Load
            VStack(alignment: .leading, spacing: 12) {
                Text("// LOAD · LAST 60m")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                VStack(spacing: 16) {
                    sparkRow(label: "CPU",  value: "38%",  color: PW.ok)
                    sparkRow(label: "MEM",  value: "9.2G", color: PW.info)
                    sparkRow(label: "NET",  value: "24Mb", color: PW.silver)
                    sparkRow(label: "DISK", value: "12%",  color: PW.silverMid)
                }
            }

            // Syslog
            VStack(alignment: .leading, spacing: 10) {
                Text("// SYSLOG · TAIL")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                syslogView
            }
            .frame(maxHeight: .infinity)
        }
        .padding(22)
        .background(PW.panel)
    }

    private func sparkRow(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(PW.FontStyle.mono(10, weight: .medium))
                    .foregroundColor(PW.silverMid)
                    .tracking(1.6)
                Spacer()
                Text(value)
                    .font(PW.FontStyle.mono(11, weight: .semibold))
                    .foregroundColor(color)
                    .tracking(0.4)
            }
            // Flat sparkline placeholder
            GeometryReader { geo in
                sparklinePath(width: geo.size.width, color: color, seed: label.count)
            }
            .frame(height: 20)
        }
    }

    private func sparklinePath(width: CGFloat, color: Color, seed: Int) -> some View {
        Canvas { context, size in
            let pts = (0..<30).map { i -> CGPoint in
                let x = CGFloat(i) / 29.0 * size.width
                let noise = sin(Double(i) * 0.5 + Double(seed)) * 4 + sin(Double(i) * 1.3 + Double(seed) * 0.7) * 2
                let y = size.height / 2 - CGFloat(noise)
                return CGPoint(x: x, y: y)
            }
            var path = Path()
            path.move(to: pts[0])
            for pt in pts.dropFirst() { path.addLine(to: pt) }
            context.stroke(path, with: .color(color), lineWidth: 1.2)
        }
    }

    private var syslogView: some View {
        let entries: [(time: String, color: Color, message: String)] = [
            ("15:42:18", PW.ok,          "session.start  rig-01  navarro      18m"),
            ("15:41:22", PW.silverMid,   "crest2.ok      rate=1000ms  drift=0"),
            ("15:40:01", PW.guardsBright,"pb              navarro     1:28.432"),
            ("15:38:44", PW.warn,        "rig-06.maint    wheelbase    code=1024"),
            ("15:34:11", PW.silverMid,   "mcp.tool        ams2_set_session  ok"),
            ("15:30:00", PW.ok,          "race.start      lap=20 weather=clear"),
            ("15:29:48", PW.silverMid,   "rig-04.checkin  rossi  walk-up"),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                HStack(alignment: .top, spacing: 10) {
                    Text(entry.time)
                        .font(PW.FontStyle.mono(10, weight: .regular))
                        .foregroundColor(PW.silverInk)
                    Text("›")
                        .font(PW.FontStyle.mono(10, weight: .regular))
                        .foregroundColor(entry.color)
                    Text(entry.message)
                        .font(PW.FontStyle.mono(10, weight: .regular))
                        .foregroundColor(PW.silver2)
                        .lineLimit(1)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PW.carbon)
        .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
    }

    // MARK: - Actions

    private func refreshStatus() async {
        isLoading = true
        error = nil
        do {
            serverStatus = try await resolvedAPI().serverStatus()
        } catch {
            self.error = "Could not reach the server: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func startServer() async {
        isLoading = true
        error = nil
        do {
            serverStatus = try await resolvedAPI().startServer()
        } catch {
            self.error = "Could not reach the server: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
