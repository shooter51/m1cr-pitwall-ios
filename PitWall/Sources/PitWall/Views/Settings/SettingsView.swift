import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @State private var addingBackend = false
    @State private var showServerDisconnectConfirm = false
    @State private var showLocationDisconnectConfirm = false
    @State private var showFactoryResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(eyebrow: "08 · SYSTEM", title: "SETTINGS") {
                Text("PITWALL · v\(Bundle.main.appVersion)")
                    .font(PW.FontStyle.mono(10, weight: .semibold))
                    .foregroundColor(PW.silverMid)
                    .tracking(1.6)
                PWTopBarDivider()
                Text("BUILD \(Bundle.main.buildNumber)")
                    .font(PW.FontStyle.mono(10, weight: .semibold))
                    .foregroundColor(PW.silverMid)
                    .tracking(1.6)
            } actions: {
                Text("SYSTEM CONFIG")
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.4)
            }

            ScrollView {
                HStack(alignment: .top, spacing: 14) {
                    // Left column
                    VStack(spacing: 0) {
                        serverPanel
                        locationPanel
                        displayPanel
                    }
                    .frame(maxWidth: .infinity)

                    // Right column (260pt fixed)
                    VStack(spacing: 0) {
                        aboutPanel
                        devicePanel
                        linksPanel
                        dangerPanel
                    }
                    .frame(width: 260)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(PW.carbon)
        }
        .background(PW.carbon)
        .sheet(isPresented: $addingBackend) {
            JoinBackendSheet().presentationDetents([.medium, .large])
        }
        .alert("Disconnect from server?", isPresented: $showServerDisconnectConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                if let current = store.current {
                    store.remove(id: current.id)
                    mc.detach()
                }
            }
        } message: {
            Text("You'll need the server address and access key to reconnect.")
        }
        .alert("Disconnect from location?", isPresented: $showLocationDisconnectConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                mc.detach()
            }
        } message: {
            Text("You'll return to the lobby.")
        }
        .alert("Factory Reset?", isPresented: $showFactoryResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.backends.forEach { store.remove(id: $0.id) }
                mc.detach()
            }
        } message: {
            Text("This will remove all saved servers and preferences.")
        }
    }

    // MARK: - Server panel

    private var serverPanel: some View {
        SettingsPanelView(accent: PW.guards, label: "CONNECTED SERVER") {
            StatusChip(.available, compact: true)
        } content: {
            // Server name
            if let current = store.current {
                Text(current.displayName.uppercased())
                    .font(PW.FontStyle.card(26))
                    .foregroundColor(PW.silver)
                    .tracking(-0.52)
                    .lineLimit(1)

                Text(current.lobbyURL.absoluteString)
                    .font(PW.FontStyle.mono(10))
                    .foregroundColor(PW.silverDim)
                    .tracking(0.8)
                    .padding(.top, 4)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Circle().fill(PW.ok).frame(width: 6, height: 6)
                    Text("CONNECTED · 12ms LATENCY")
                        .font(PW.FontStyle.mono(9))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.0)
                }
                .padding(.top, 10)
            } else {
                Text("NO SERVER CONNECTED")
                    .font(PW.FontStyle.mono(11, weight: .bold))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
            }

            // Saved servers
            Rectangle().fill(PW.line).frame(height: 1).padding(.vertical, 14)

            Text("// SAVED SERVERS · \(store.backends.count)")
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundColor(PW.silverDim)
                .tracking(2.2)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(store.backends) { backend in
                    let isCurrent = backend.id == store.currentId

                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(backend.displayName.uppercased())
                                .font(PW.FontStyle.mono(11, weight: .semibold))
                                .foregroundColor(isCurrent ? PW.silver : PW.silverMid)
                                .tracking(0.4)
                                .lineLimit(1)
                            Text(backend.lobbyURL.absoluteString)
                                .font(PW.FontStyle.mono(10))
                                .foregroundColor(PW.silverDim)
                                .tracking(0.8)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        if isCurrent {
                            Text("CURRENT")
                                .font(PW.FontStyle.mono(8, weight: .bold))
                                .foregroundColor(PW.guardsBright)
                                .tracking(1.8)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PW.guardsBright.opacity(0.14))
                        } else {
                            Button("SWITCH") {
                                store.setCurrent(backend.id)
                                mc.switchBackend(backend)
                            }
                            .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(isCurrent ? PW.guards.opacity(0.06) : Color.clear)
                    .overlay(alignment: .leading) {
                        if isCurrent {
                            Rectangle().fill(PW.guards).frame(width: 2)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("+ ADD SERVER") { addingBackend = true }
                    .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))

                if store.current != nil {
                    Button("DISCONNECT") { showServerDisconnectConfirm = true }
                        .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Location panel

    private var locationPanel: some View {
        SettingsPanelView(accent: PW.ok, label: "CONNECTED LOCATION") {
            HStack(spacing: 8) {
                Circle().fill(PW.ok).frame(width: 6, height: 6)
                StatusChip(.available, compact: true)
            }
        } content: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text((mc.attached?.name ?? "NO LOCATION").uppercased())
                        .font(PW.FontStyle.title(22))
                        .foregroundColor(PW.silver)
                        .tracking(-0.44)
                        .lineLimit(1)

                    if let node = mc.attached {
                        Text("SLUG · \(node.slug)")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(2.0)

                        HStack(spacing: 8) {
                            Text("\(node.live.activeSessions) RIGS")
                                .font(PW.FontStyle.mono(9, weight: .bold))
                                .foregroundColor(PW.ok)
                                .tracking(1.8)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(PW.ok.opacity(0.16))

                            Text("LOC · \(node.id.prefix(8).uppercased())")
                                .font(PW.FontStyle.mono(9))
                                .foregroundColor(PW.silverDim)
                                .tracking(1.6)
                        }
                        .padding(.top, 8)
                    }
                }

                Spacer(minLength: 0)

                Button("DISCONNECT") { showLocationDisconnectConfirm = true }
                    .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
                    .disabled(mc.attached == nil)
            }
        }
    }

    // MARK: - Display panel

    private var displayPanel: some View {
        SettingsPanelView(label: "DISPLAY") {
            EmptyView()
        } content: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THEME")
                        .font(PW.FontStyle.mono(11, weight: .semibold))
                        .foregroundColor(PW.silver)
                        .tracking(0.8)
                    Text("APPEARANCE MODE")
                        .font(PW.FontStyle.mono(9))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.6)
                }

                Spacer()

                // Segmented: DARK active / LIGHT inactive
                HStack(spacing: 0) {
                    Text("DARK")
                        .font(PW.FontStyle.mono(10, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(1.6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(PW.guards)
                        .clipShape(CutShape())

                    Text("LIGHT")
                        .font(PW.FontStyle.mono(10, weight: .bold))
                        .foregroundColor(PW.silverInk)
                        .tracking(1.6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(PW.panel3)
                        .clipShape(CutShape())
                        .padding(.leading, -2)
                }
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(PW.lineSoft).frame(height: 1) }

            Text("LIGHT MODE IS NOT AVAILABLE IN THIS VERSION.")
                .font(PW.FontStyle.mono(9))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .padding(.top, 8)
        }
    }

    // MARK: - About panel

    private var aboutPanel: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("// ABOUT")
                        .font(PW.FontStyle.mono(9, weight: .bold))
                        .foregroundColor(PW.guardsBright)
                        .tracking(2.2)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(PW.line).frame(height: 1) }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("PIT")
                            .font(PW.FontStyle.h1(40))
                            .foregroundColor(PW.guards)
                            .tracking(-1.2)
                        Text("WALL")
                            .font(PW.FontStyle.h1(40))
                            .foregroundColor(PW.silver)
                            .tracking(-1.2)
                    }

                    Text("VERSION · \(Bundle.main.appVersion)")
                        .font(PW.FontStyle.mono(11, weight: .bold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.6)
                        .padding(.top, 6)

                    Text("BUILD · \(Bundle.main.buildNumber)")
                        .font(PW.FontStyle.mono(9))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.4)
                        .padding(.top, 2)

                    Text("AMS2 PITWALL — M1 CIRCUIT")
                        .font(PW.FontStyle.mono(9))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.6)
                        .padding(.top, 10)

                    Text("© 2026 M1 CIRCUIT RACING")
                        .font(PW.FontStyle.mono(9))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.6)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 14)
            }
            .background(PW.panel)
            .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
            .clipShape(Rectangle())
            .padding(.bottom, 12)

            // Corner stripes
            CornerStripes(size: 60)
                .allowsHitTesting(false)
                .padding(.top, 1)
                .padding(.trailing, 1)
        }
    }

    // MARK: - Device panel

    private var devicePanel: some View {
        SettingsPanelView(label: "DEVICE") {
            EmptyView()
        } content: {
            Text("DEVICE ID")
                .font(PW.FontStyle.mono(9))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .padding(.bottom, 4)

            let deviceId = mc.deviceId
            let suffix = String(deviceId.suffix(4)).uppercased()
            let prefix = String(deviceId.dropLast(4))

            HStack(spacing: 0) {
                Text(prefix.isEmpty ? "iPad · iPadOS" : prefix)
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.silverInk)
                    .tracking(1.2)
                    .lineLimit(1)
                Text(suffix)
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.guards)
                    .tracking(1.2)
            }

            Rectangle().fill(PW.line).frame(height: 1).padding(.vertical, 10)

            Text("ASSIGNED OPERATOR")
                .font(PW.FontStyle.mono(9))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .padding(.bottom, 2)

            Text("TOM GIBSON")
                .font(PW.FontStyle.mono(11, weight: .bold))
                .foregroundColor(PW.silver)
                .tracking(1.4)

            Text("ADMIN ROLE · \((mc.attached?.name ?? "PITWALL").uppercased())")
                .font(PW.FontStyle.mono(9))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .padding(.top, 2)
        }
    }

    // MARK: - Links panel

    private var linksPanel: some View {
        SettingsPanelView(label: "LINKS") {
            EmptyView()
        } content: {
            let items: [(color: Color, label: String, sub: String, systemImage: String)] = [
                (PW.info, "WEB DASHBOARD", "pitwall.m1circuit.com", "arrow.up.right.square"),
                (PW.info, "SUPPORT", "ops@m1circuit.com", "envelope"),
                (PW.silverDim, "DIAGNOSTICS", "EXPORT LOG BUNDLE", "info.circle"),
            ]

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 8) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 12))
                            .foregroundColor(item.color)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(item.color)
                                .tracking(1.6)
                            Text(item.sub)
                                .font(PW.FontStyle.mono(9))
                                .foregroundColor(PW.silverDim)
                                .tracking(1.0)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(PW.silverInk)
                    }
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) {
                        if idx < items.count - 1 {
                            Rectangle().fill(PW.lineSoft).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Danger zone panel

    private var dangerPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("// DANGER ZONE")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.guardsBright)
                    .tracking(2.2)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(PW.guards.opacity(0.15)).frame(height: 1) }

            VStack(alignment: .leading, spacing: 10) {
                Text("RESET ALL LOCAL DATA INCLUDING SAVED SERVERS AND PREFERENCES.")
                    .font(PW.FontStyle.mono(9))
                    .foregroundColor(PW.silverDim)
                    .tracking(1.6)
                    .lineSpacing(3)

                Button("FACTORY RESET") { showFactoryResetConfirm = true }
                    .buttonStyle(PrimaryButtonStyle(.danger, compact: true))
                    .frame(maxWidth: .infinity)
            }
            .padding(14)
        }
        .background(PW.panel)
        .overlay(Rectangle().stroke(PW.guards.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Settings panel wrapper

private struct SettingsPanelView<Chip: View, Content: View>: View {
    var accent: Color? = nil
    let label: String
    @ViewBuilder var chip: Chip
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("// \(label)")
                    .font(PW.FontStyle.mono(9, weight: .bold))
                    .foregroundColor(PW.guardsBright)
                    .tracking(2.2)
                Spacer()
                chip
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(PW.line).frame(height: 1) }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PW.panel)
        .overlay(
            Rectangle()
                .stroke(PW.line, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            if let accent {
                Rectangle().fill(accent).frame(width: accent == PW.line ? 1 : 3)
            }
        }
        .padding(.bottom, 12)
    }
}

// MARK: - Bundle version helpers

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
    var buildNumber: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}
