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

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()

            VStack(spacing: PW.sectionSpacing) {
                Spacer()

                // Status pill
                statusPill

                // IP address
                if let ip = serverStatus?.ip {
                    Text(ip)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(PW.silverMid)
                }

                // Start button
                if serverStatus?.status == .stopped {
                    Button("START SERVER") {
                        showConfirmStart = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                } else if serverStatus?.status == .starting || serverStatus?.status == .stopping {
                    ProgressView()
                        .tint(PW.guards)
                }

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(PW.guards)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("Server auto-stops after 2 hours idle.")
                    .font(.system(size: 12))
                    .foregroundStyle(PW.silverDim)

                Spacer()
            }
            .padding(PW.cardPadding)
        }
        .navigationTitle("Server Control")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await refreshStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .confirmationDialog(
            "Start Server?",
            isPresented: $showConfirmStart,
            titleVisibility: .visible
        ) {
            Button("Start Server", role: .destructive) {
                Task { await startServer() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will start the EC2 instance. It may take 1-2 minutes to become available.")
        }
        .task { await refreshStatus() }
    }

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 10) {
            StatusDot(status: currentStatus)
                .scaleEffect(1.5)
            Text(currentStatus.displayName.uppercased())
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(PW.silver)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(PW.panel)
    }

    private var currentStatus: ServerStatus.EC2Status {
        serverStatus?.status ?? viewModel.serverStatus
    }

    // MARK: - Actions

    private func refreshStatus() async {
        isLoading = true
        error = nil
        do {
            serverStatus = try await resolvedAPI().serverStatus()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func startServer() async {
        isLoading = true
        error = nil
        do {
            serverStatus = try await resolvedAPI().startServer()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
