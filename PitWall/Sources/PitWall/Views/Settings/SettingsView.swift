import SwiftUI

struct SettingsView: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @State private var addingBackend = false

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            Form {
                // Current backend
                Section {
                    if let current = store.current {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.displayName).foregroundStyle(PW.silver)
                            Text(current.lobbyURL.absoluteString)
                                .font(.system(size: 11).monospaced())
                                .foregroundStyle(PW.silverDim)
                        }
                    } else {
                        Text("No backend connected").foregroundStyle(PW.silverDim)
                    }
                } header: {
                    Text("Current Backend").foregroundStyle(PW.silverDim)
                }

                // Other backends — switch with one tap.
                if store.backends.count > 1 {
                    Section {
                        ForEach(store.backends) { backend in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(backend.displayName).foregroundStyle(PW.silver)
                                    Text(backend.lobbyURL.absoluteString)
                                        .font(.system(size: 10).monospaced())
                                        .foregroundStyle(PW.silverDim)
                                }
                                Spacer()
                                if backend.id == store.currentId {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PW.ok)
                                } else {
                                    Button("Switch") {
                                        store.setCurrent(backend.id)
                                        mc.switchBackend(backend)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .onDelete { idx in
                            for i in idx { store.remove(id: store.backends[i].id) }
                        }
                    } header: {
                        Text("Saved Backends").foregroundStyle(PW.silverDim)
                    }
                }

                Section {
                    Button("Add a backend…") { addingBackend = true }
                        .foregroundStyle(PW.silver)
                    if let current = store.current {
                        Button("Remove current backend", role: .destructive) {
                            store.remove(id: current.id)
                            mc.detach()
                        }
                    }
                }

                // Current Mobile Command attachment
                Section {
                    HStack {
                        Label(mc.attached?.name ?? "—", systemImage: "rectangle.connected.to.line.below")
                            .foregroundStyle(PW.silver)
                        Spacer()
                        Button("Detach", role: .destructive) {
                            mc.detach()
                        }
                        .disabled(mc.attached == nil)
                    }
                } header: {
                    Text("Mobile Command").foregroundStyle(PW.silverDim)
                }

                // Appearance
                Section {
                    HStack {
                        Text("Theme").foregroundStyle(PW.silver)
                        Spacer()
                        Text("Dark (always)").foregroundStyle(PW.silverDim)
                    }
                } header: {
                    Text("Appearance").foregroundStyle(PW.silverDim)
                }

                // About
                Section {
                    LabeledContent("App Version", value: Bundle.main.appVersion)
                    if let current = store.current {
                        Link("Web Dashboard", destination: webDashboardURL(for: current))
                    }
                } header: {
                    Text("About").foregroundStyle(PW.silverDim)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PW.carbon)
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $addingBackend) {
            JoinBackendSheet().presentationDetents([.medium, .large])
        }
    }

    private func webDashboardURL(for backend: Backend) -> URL {
        // The web dashboard sits at the same origin as the lobby, without the /lobby path.
        var components = URLComponents(url: backend.lobbyURL, resolvingAgainstBaseURL: false)
        components?.path = ""
        return components?.url ?? backend.lobbyURL
    }
}

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
