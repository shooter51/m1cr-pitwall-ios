import SwiftUI

/// Sheet for adding an existing backend by URL + client key.
struct JoinBackendSheet: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = "https://"
    @State private var clientKey = ""
    @State private var testing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Friendly name (e.g. Tom's House)", text: $name)
                    TextField("Server Address", text: $urlString)
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    SecureField("Access Key", text: $clientKey)
                        .autocorrectionDisabled(true)
                } header: {
                    Text("Server Details")
                } footer: {
                    Text("Your server address looks like https://pitwall.example.com. The access key was set up when the server was installed — ask your admin if you don't have it.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 12))
                    }
                }
            }
            .navigationTitle("Connect to Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Connect") { Task { await connect() } }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        URL(string: urlString.trimmingCharacters(in: .whitespaces)) != nil
        && !clientKey.isEmpty
    }

    private func connect() async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Invalid URL"
            return
        }
        testing = true; defer { testing = false }
        errorMessage = nil

        // Test the connection by hitting /lobby/nodes once before saving.
        var req = URLRequest(url: url.appendingPathComponent("lobby/nodes"))
        req.setValue(clientKey, forHTTPHeaderField: "X-PitWall-Key")
        req.timeoutInterval = 8

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Couldn't connect to the server. Check that the address is correct."
                return
            }
            if http.statusCode == 401 {
                errorMessage = "Access key not accepted. Double-check the key and try again."
                return
            }
            if !(200..<300).contains(http.statusCode) {
                errorMessage = "Server error (code \(http.statusCode)). Try again or contact your admin."
                return
            }
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
            return
        }

        let backend = Backend(
            name: name.trimmingCharacters(in: .whitespaces),
            lobbyURL: url,
            clientKey: clientKey,
            lastConnectedAt: Date(),
        )
        store.add(backend)
        store.setCurrent(backend.id)
        mc.switchBackend(backend)
        dismiss()
    }
}
