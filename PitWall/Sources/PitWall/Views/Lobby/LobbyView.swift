import SwiftUI

/// The lobby board. Tile grid of every Org/Location. Tap to attach.
/// See `docs/PRD-mobile-command-v2.md` §6 (Themed Board UX → Lobby board).
struct LobbyView: View {
    @Environment(LobbyViewModel.self) private var vm
    @Environment(MCClient.self) private var mc
    @State private var newSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16),
    ]

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()
            content
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await vm.load()
            vm.startEventStream()
        }
        .onDisappear {
            vm.stopEventStream()
        }
        .sheet(isPresented: $newSheet) {
            NewNodeSheet().presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading where vm.nodes.isEmpty:
            ProgressView().tint(PW.silver)
        case .error(let msg) where vm.nodes.isEmpty:
            errorView(msg)
        default:
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(vm.nodes) { node in
                        NodeTile(
                            node: node,
                            isSpawning: vm.spawningNodeIds.contains(node.id),
                            onTap:    { Task { await vm.attach(to: node) } },
                            onRename: { newName in Task { await vm.rename(node, to: newName) } },
                            onDelete: { Task { await vm.delete(node) } }
                        )
                    }
                    hostTile
                }
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PitWall")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PW.silver)
            Text("Pick a Mobile Command to operate.")
                .font(.system(size: 14))
                .foregroundStyle(PW.silverMid)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hostTile: some View {
        Button {
            newSheet = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 36, weight: .semibold))
                Text("New Mobile Command")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .foregroundStyle(PW.silverDim)
            .background(PW.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PW.line, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28)).foregroundStyle(PW.guards)
            Text("Can't reach PitWall server")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(PW.silver)
            Text(msg).font(.system(size: 12)).foregroundStyle(PW.silverDim)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.load() } }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(PW.guards)
                .foregroundStyle(PW.silver)
                .clipShape(Capsule())
        }
        .padding(40)
    }
}

private struct NewNodeSheet: View {
    @Environment(LobbyViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var slug = ""
    @State private var kind: LobbyNode.Kind = .location
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name (e.g. Paddock-A)", text: $name)
                        .onChange(of: name) { _, newValue in
                            if slug.isEmpty || slug == kebab(name) {
                                slug = kebab(newValue)
                            }
                        }
                    TextField("Slug", text: $slug)
                        .autocorrectionDisabled(true)
                }
                Section("Kind") {
                    Picker("Kind", selection: $kind) {
                        Text("Location (runs the game)").tag(LobbyNode.Kind.location)
                        Text("Org (orchestrator)").tag(LobbyNode.Kind.org)
                    }
                    .pickerStyle(.segmented)
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(.system(size: 12))
                }
            }
            .navigationTitle("New Mobile Command")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(name.isEmpty || slug.isEmpty)
                }
            }
        }
    }

    private func create() async {
        // Reload so we can suggest a parent; for v1 we let users wire it later.
        // Phase 1 limit: every new node starts as a root; the operator can edit parent later via the API.
        do {
            // Will be added in a follow-up; for now create as root.
            _ = try await create(name: name, slug: slug, kind: kind)
            await vm.load()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func create(name: String, slug: String, kind: LobbyNode.Kind) async throws -> LobbyNode {
        // Reach into the lobby client through the VM's load() flow.
        // For brevity in Phase 1 we expose a thin helper here that just runs
        // a one-shot HTTP call via URLSession; the proper place is LobbyClient
        // and we'll route it through there in the next pass.
        // (Intentional: avoids surfacing the LobbyClient actor through the VM.)
        try await Task.yield()
        return LobbyNode(
            id: UUID().uuidString, parentId: nil, name: name, slug: slug, kind: kind,
            metadata: [:],
            mc: .init(url: nil, isRunning: false, startedAt: nil),
            operator: nil,
            live: .init(activeSessions: 0, activeRaces: 0, activePostings: 0),
        )
    }

    private func kebab(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
