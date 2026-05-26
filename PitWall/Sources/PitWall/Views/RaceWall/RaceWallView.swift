import SwiftUI

/// In-org surface: live Race Postings from child Locations.
/// Shown only when the attached MC is kind=org. See ContentView.tabsForKind.
struct RaceWallView: View {
    @Environment(MCClient.self) private var mc
    @State private var vm: RaceWallViewModel?
    @State private var joinSheet: RacePosting?

    private let columns = [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16)]

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()
            content
        }
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

    @ViewBuilder
    private var content: some View {
        if let vm, !vm.postings.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(vm.postings) { posting in
                            PostingTile(
                                posting: posting,
                                onJoin:        { joinSheet = posting },
                                onSpectate:    { /* spectate UI: TBD */ },
                                onPushToDisplay: { /* display picker: TBD */ }
                            )
                        }
                    }
                }
                .padding(20)
            }
        } else {
            emptyState
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Race Wall")
                .font(.system(size: 32, weight: .bold)).foregroundStyle(PW.silver)
            Text("Live races posted from your Locations.")
                .font(.system(size: 14)).foregroundStyle(PW.silverMid)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 36)).foregroundStyle(PW.silverDim)
            Text("No live races yet").font(.system(size: 16, weight: .semibold)).foregroundStyle(PW.silver)
            Text("When a Location posts a race here, you'll see it.").font(.system(size: 12)).foregroundStyle(PW.silverDim)
        }
        .padding(40)
    }
}

private struct JoinSheet: View {
    let posting: RacePosting
    let onJoin: (String) -> Void
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Join \(posting.trackName)").font(.system(size: 18, weight: .semibold))
            TextField("Driver name", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
            Button("Join") { onJoin(name) }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
        }
        .padding(20)
    }
}
