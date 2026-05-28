import SwiftUI

/// Shown when no Backend is configured yet (first launch, or after removing all saved backends).
struct BackendPickerView: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @State private var sheet: Sheet?

    enum Sheet: Identifiable {
        case join, create
        var id: Int { self == .join ? 0 : 1 }
    }

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            // Decorative diagonal corner stripes
            CornerStripes(size: 300)
                .opacity(0.18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 80, y: -80)
                .allowsHitTesting(false)

            CornerStripes(size: 220)
                .opacity(0.14)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -60, y: 60)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top chrome bar
                HStack {
                    HStack(spacing: 6) {
                        // Brand mark
                        HStack(spacing: 0) {
                            Text("M1")
                                .font(PW.FontStyle.title(24))
                                .foregroundColor(PW.guards)
                                .tracking(-0.48)
                            Text("·CIRCUIT")
                                .font(PW.FontStyle.title(24))
                                .foregroundColor(PW.silver)
                                .tracking(-0.48)
                        }
                        .textCase(.uppercase)

                        Rectangle().fill(PW.line).frame(width: 1, height: 18)

                        Text("PITWALL · v3.2.1")
                            .font(PW.FontStyle.mono(10, weight: .semibold))
                            .foregroundColor(PW.silverMid)
                            .tracking(2.2)
                    }

                    Spacer()

                    Text("FIRST LAUNCH · NO BACKEND")
                        .font(PW.FontStyle.mono(10, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PW.line).frame(height: 1)
                }

                // Center content
                VStack(spacing: 28) {
                    Spacer()

                    // Hero text
                    VStack(spacing: 0) {
                        Text("// LIGHTS OUT — AWAY WE GO.")
                            .font(PW.FontStyle.mono(10, weight: .bold))
                            .foregroundColor(PW.guardsBright)
                            .tracking(3.2)

                        VStack(alignment: .center, spacing: 0) {
                            Text("PITWALL.")
                                .font(PW.FontStyle.hero(124))
                                .foregroundColor(PW.silver)
                                .tracking(-3.72)
                            Text("OPS GRADE.")
                                .font(PW.FontStyle.hero(124))
                                .foregroundColor(PW.guards)
                                .tracking(-3.72)
                        }
                        .padding(.vertical, 14)

                        Text("Connect to a venue's PitWall server to start operating.")
                            .font(PW.FontStyle.body(14))
                            .foregroundColor(PW.silverMid)
                            .padding(.top, 4)
                    }
                    .multilineTextAlignment(.center)

                    // Two main option cards
                    HStack(spacing: 0) {
                        // Connect
                        Button { sheet = .join } label: {
                            ZStack(alignment: .top) {
                                Rectangle().fill(PW.guards).frame(height: 3)
                                VStack(alignment: .leading, spacing: 0) {
                                    Spacer().frame(height: 3)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("// 01 · CONNECT")
                                            .font(PW.FontStyle.mono(9, weight: .bold))
                                            .foregroundColor(PW.guardsBright)
                                            .tracking(2.4)

                                        Text("JOIN A SERVER")
                                            .font(PW.FontStyle.title(38))
                                            .foregroundColor(PW.silver)
                                            .tracking(-0.76)

                                        Text("Already deployed? Paste the server URL and access key from your venue admin to attach.")
                                            .font(PW.FontStyle.body(12))
                                            .foregroundColor(PW.silverMid)
                                            .lineSpacing(4)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer().frame(height: 8)

                                        HStack {
                                            Text("CONNECT →")
                                                .font(PW.FontStyle.mono(11, weight: .bold))
                                                .foregroundColor(.white)
                                                .tracking(1.6)
                                                .padding(.horizontal, 30)
                                                .padding(.vertical, 12)
                                                .background(PW.guards)
                                                .overlay(Rectangle().stroke(PW.guards, lineWidth: 1))
                                                .clipShape(CutShape())
                                            Spacer()
                                        }
                                    }
                                    .padding(26)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .background(PW.panel)

                        Rectangle().fill(PW.line).frame(width: 1)

                        // Set up new
                        Button { sheet = .create } label: {
                            ZStack(alignment: .top) {
                                Rectangle().fill(PW.info.opacity(0.6)).frame(height: 3)
                                VStack(alignment: .leading, spacing: 0) {
                                    Spacer().frame(height: 3)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("// 02 · DEPLOY")
                                            .font(PW.FontStyle.mono(9, weight: .bold))
                                            .foregroundColor(PW.info)
                                            .tracking(2.4)

                                        Text("SET UP NEW")
                                            .font(PW.FontStyle.title(38))
                                            .foregroundColor(PW.silver)
                                            .tracking(-0.76)

                                        Text("Stand up your own PitWall on AWS, your venue PC, or Cloudflare. Guided 5-step wizard.")
                                            .font(PW.FontStyle.body(12))
                                            .foregroundColor(PW.silverMid)
                                            .lineSpacing(4)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer().frame(height: 8)

                                        HStack {
                                            Text("START WIZARD →")
                                                .font(PW.FontStyle.mono(11, weight: .bold))
                                                .foregroundColor(PW.silver)
                                                .tracking(1.6)
                                                .padding(.horizontal, 30)
                                                .padding(.vertical, 12)
                                                .overlay(Rectangle().stroke(PW.lineStrong, lineWidth: 1))
                                                .clipShape(CutShape())
                                            Spacer()
                                        }
                                    }
                                    .padding(26)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .background(PW.carbon2)
                    }
                    .overlay(Rectangle().stroke(PW.line, lineWidth: 1))
                    .frame(maxWidth: 740)

                    // Saved servers list
                    if !store.backends.isEmpty {
                        savedServersSection
                            .frame(maxWidth: 740)
                    }

                    Spacer()
                }
                .padding(.horizontal, 80)

                // Bottom chrome bar
                HStack {
                    Text("M1CR · PIT WALL · BUILD 3.2.1 · IPADOS 17.4")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.2)
                    Spacer()
                    Text("SUPPORT · OPS@M1CR.COM · +1 805 748 3680")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.2)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(PW.line).frame(height: 1)
                }
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .join:   JoinBackendSheet().presentationDetents([.medium, .large])
            case .create: CreateBackendSheet().presentationDetents([.large])
            }
        }
    }

    // MARK: - Saved servers

    private var savedServersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("// SAVED SERVERS · \(store.backends.count)")
                .font(PW.FontStyle.mono(9, weight: .bold))
                .foregroundColor(PW.silverDim)
                .tracking(2.2)

            VStack(spacing: 4) {
                ForEach(store.backends) { backend in
                    Button {
                        store.setCurrent(backend.id)
                        mc.switchBackend(backend)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(PW.ok)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(backend.displayName.uppercased())
                                    .font(PW.FontStyle.mono(12, weight: .semibold))
                                    .foregroundColor(PW.silver)
                                    .tracking(0.4)
                                Text(backend.lobbyURL.absoluteString)
                                    .font(PW.FontStyle.mono(9, weight: .semibold))
                                    .foregroundColor(PW.silverDim)
                                    .tracking(1.2)
                            }

                            Spacer()

                            if store.currentId == backend.id {
                                Text("CURRENT")
                                    .font(PW.FontStyle.mono(9, weight: .bold))
                                    .foregroundColor(PW.guardsBright)
                                    .tracking(2.2)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(PW.silverDim)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(PW.panel)
                        .overlay(
                            Rectangle().stroke(
                                store.currentId == backend.id ? PW.guards : PW.line,
                                lineWidth: 1
                            )
                        )
                        .overlay(alignment: .leading) {
                            if store.currentId == backend.id {
                                Rectangle().fill(PW.guards).frame(width: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
