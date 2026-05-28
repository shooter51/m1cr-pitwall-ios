import SwiftUI

/// Shown after picking a backend; selects a location or org to attach.
struct LobbyView: View {
    @Environment(LobbyViewModel.self) private var vm
    @Environment(MCClient.self) private var mc
    @State private var newSheet = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top chrome bar
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        HStack(spacing: 0) {
                            Text("M1")
                                .font(PW.FontStyle.title(22))
                                .foregroundColor(PW.guards)
                                .tracking(-0.44)
                            Text("·CIRCUIT")
                                .font(PW.FontStyle.title(22))
                                .foregroundColor(PW.silver)
                                .tracking(-0.44)
                        }
                        .textCase(.uppercase)

                        Rectangle().fill(PW.line).frame(width: 1, height: 18)

                        Text("PITWALL · TOM'S PITWALL")
                            .font(PW.FontStyle.mono(10, weight: .semibold))
                            .foregroundColor(PW.silverMid)
                            .tracking(2.2)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            LiveDot(color: PW.ok, size: 7)
                            Text("CONNECTED · 18ms")
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.ok)
                                .tracking(2.2)
                        }

                        Rectangle().fill(PW.line).frame(width: 1, height: 16)

                        Button("SWITCH BACKEND") {}
                            .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PW.line).frame(height: 1)
                }

                // Headline + actions
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("// LOBBY · SELECT A NODE TO ATTACH")
                            .font(PW.FontStyle.mono(10, weight: .bold))
                            .foregroundColor(PW.guardsBright)
                            .tracking(2.4)

                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text("CHOOSE ")
                                .font(PW.FontStyle.h1(56))
                                .foregroundColor(PW.silver)
                                .tracking(-1.68)
                            Text("YOUR PIT.")
                                .font(PW.FontStyle.h1(56))
                                .foregroundColor(PW.guards)
                                .tracking(-1.68)
                        }
                        .textCase(.uppercase)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button("REFRESH") { Task { await vm.load() } }
                            .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                        Button("+ NEW NODE") { newSheet = true }
                            .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)

                // Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.nodes) { node in
                            NodeTile(
                                node: node,
                                isSpawning: vm.spawningNodeIds.contains(node.id),
                                onTap:    { Task { await vm.attach(to: node) } },
                                onRename: { newName in Task { await vm.rename(node, to: newName) } },
                                onDelete: { Task { await vm.delete(node) } }
                            )
                        }

                        // Add node tile
                        Button { newSheet = true } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Rectangle()
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundColor(PW.guards)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .regular))
                                        .foregroundColor(PW.guardsBright)
                                }
                                Text("ADD LOCATION / ORG")
                                    .font(PW.FontStyle.mono(10, weight: .semibold))
                                    .foregroundColor(PW.silverMid)
                                    .tracking(2.2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 158)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                                    )
                                    .foregroundColor(PW.lineStrong)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                }
                .refreshable { await vm.load() }

                // Footer bar
                HStack {
                    Text("\(vm.nodes.filter(\.mc.isRunning).count) ONLINE · \(vm.nodes.filter { !$0.mc.isRunning }.count) OFFLINE · SYNCED 18s AGO")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.2)
                    Spacer()
                    Text("LONG-PRESS · RENAME / DELETE")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.2)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(PW.carbon2)
                .overlay(alignment: .top) {
                    Rectangle().fill(PW.line).frame(height: 1)
                }
            }
        }
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
}

private struct NewNodeSheet: View {
    @Environment(LobbyViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: LobbyNode.Kind = .location
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PW.carbon.ignoresSafeArea()
                Form {
                    Section {
                        TextField("Name (e.g. Tom's House)", text: $name)
                    }
                    Section("Type") {
                        Picker("Type", selection: $kind) {
                            Text("Location").tag(LobbyNode.Kind.location)
                            Text("Organization").tag(LobbyNode.Kind.org)
                        }
                        .pickerStyle(.segmented)
                        Text(kind == .location
                             ? "A single venue with simulators"
                             : "A group of venues (multi-location only)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let error {
                        Text(error).foregroundStyle(.red).font(.system(size: 12))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func create() async {
        let slug = kebab(name)
        do {
            _ = try await vm.createNode(name: name, slug: slug, kind: kind)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func kebab(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
