import SwiftUI

struct RaceWallView: View {
    @Environment(MCClient.self) private var mc
    @State private var vm: RaceWallViewModel?
    @State private var joinSheet: RacePosting?
    @State private var activeFilter = "ALL"

    private let columns = Array(repeating: GridItem(.flexible(), spacing: PW.gap2), count: 3)
    private let filters = ["ALL", "LIVE", "OPEN SLOTS", "GT3"]

    var body: some View {
        VStack(spacing: 0) {
            PWTopBar(
                eyebrow: "05 · MEDIA · ORG-ONLY",
                title: "Race Wall"
            ) {
                Text("ORG · M1CR · 12 LOCATIONS")
                PWTopBarDivider()
                Text("POSTINGS · \(vm?.postings.count ?? 0) ACTIVE")
                PWTopBarDivider()
                HStack(spacing: 6) {
                    LiveDot(color: PW.ok, size: 6)
                    Text("SYNCED")
                }
            } actions: {
                Button("SYNC") {}
                    .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                Button("POST RACE") {}
                    .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
            }

            // Body
            VStack(alignment: .leading, spacing: 0) {
                // Section header + filters
                HStack {
                    Text("// LIVE FROM SISTER LOCATIONS")
                        .pwEyebrow()

                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { f in
                            let sel = activeFilter == f
                            Button(f) { activeFilter = f }
                                .font(PW.FontStyle.mono(10, weight: .semibold))
                                .foregroundColor(sel ? PW.guardsBright : PW.silverMid)
                                .tracking(1.6)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(sel ? PW.guardsBright.opacity(0.08) : Color.clear)
                                .overlay(
                                    Rectangle().stroke(sel ? PW.guards : PW.lineStrong, lineWidth: 1)
                                )
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Grid
                if let vm {
                    if vm.postings.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: PW.gap2) {
                                ForEach(vm.postings) { posting in
                                    PostingTile(posting: posting, onJoin: { joinSheet = posting })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                        .refreshable { await vm.load() }
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PW.carbon)
        .task {
            if vm == nil { vm = RaceWallViewModel(mc: mc) }
            await vm?.load()
        }
        .sheet(item: $joinSheet) { posting in
            JoinSheet(posting: posting, onJoin: { name in
                Task { await vm?.join(posting: posting, driverName: name); joinSheet = nil }
            })
            .presentationDetents([.fraction(0.35)])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("NO LIVE RACES FROM SISTER LOCATIONS")
                .font(PW.FontStyle.mono(11, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(1.6)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct JoinSheet: View {
    let posting: RacePosting
    let onJoin: (String) -> Void
    @State private var name = ""
    @State private var isJoining = false

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("JOIN · \(posting.trackName.uppercased())")
                    .font(PW.FontStyle.title(22))
                    .foregroundColor(PW.silver)
                    .tracking(-0.44)

                TextField("Driver name", text: $name)
                    .textFieldStyle(PWTextFieldStyle())
                    .padding(.horizontal, 20)
                    .disabled(isJoining)

                Button {
                    isJoining = true
                    onJoin(name)
                } label: {
                    if isJoining {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text("JOIN →")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(.primary))
                .disabled(name.isEmpty || isJoining)
            }
            .padding(20)
        }
    }
}
