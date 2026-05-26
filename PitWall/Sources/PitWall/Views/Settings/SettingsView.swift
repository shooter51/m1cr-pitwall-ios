import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?
    @State private var serverURL = "https://pitwall.m1circuit.com"

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            Form {
                // Connection
                Section {
                    TextField("Server URL", text: $serverURL)
                        .autocorrectionDisabled(true)
                        .foregroundStyle(PW.silver)
                } header: {
                    Text("Connection")
                        .foregroundStyle(PW.silverDim)
                }

                // Auth
                Section {
                    if authManager.isAuthenticated {
                        HStack {
                            Label("Authenticated", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(PW.ok)
                            Spacer()
                            Button("Log Out", role: .destructive) {
                                authManager.logout()
                            }
                        }
                    } else {
                        TextField("Username", text: $username)
                            .autocorrectionDisabled(true)
                            .foregroundStyle(PW.silver)

                        SecureField("Password", text: $password)
                            .foregroundStyle(PW.silver)

                        if let error = loginError {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(PW.guards)
                        }

                        Button {
                            Task { await login() }
                        } label: {
                            if isLoggingIn {
                                ProgressView()
                            } else {
                                Text("Log In")
                            }
                        }
                        .disabled(username.isEmpty || password.isEmpty || isLoggingIn)
                    }
                } header: {
                    Text("Authentication")
                        .foregroundStyle(PW.silverDim)
                }

                // Appearance
                Section {
                    HStack {
                        Text("Theme")
                            .foregroundStyle(PW.silver)
                        Spacer()
                        Text("Dark (always)")
                            .foregroundStyle(PW.silverDim)
                    }
                } header: {
                    Text("Appearance")
                        .foregroundStyle(PW.silverDim)
                }

                // About
                Section {
                    LabeledContent("App Version", value: Bundle.main.appVersion)
                    Link("Web Dashboard", destination: URL(string: serverURL)!)
                } header: {
                    Text("About")
                        .foregroundStyle(PW.silverDim)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PW.carbon)
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func login() async {
        isLoggingIn = true
        loginError = nil
        let url = URL(string: serverURL) ?? URL(string: "https://pitwall.m1circuit.com")!
        let tempAuth = AuthManager(baseURL: url)
        do {
            try await tempAuth.login(username: username, password: password)
            // On success, login the real authManager
            try await authManager.login(username: username, password: password)
        } catch {
            loginError = error.localizedDescription
        }
        isLoggingIn = false
    }
}

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
