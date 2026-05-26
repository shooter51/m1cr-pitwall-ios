import SwiftUI

/// Sheet explaining how to bring up a brand-new PitWall backend. The iOS app
/// can't provision the server itself, but it walks the operator through what's
/// needed and hands off to JoinBackendSheet when they've got it running.
struct CreateBackendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showJoin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring up a new backend")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(PW.silver)
                        Text("PitWall's server is a small Docker stack on a Linux VPS. You provision it once, then connect this app to it.")
                            .font(.system(size: 13))
                            .foregroundStyle(PW.silverMid)
                    }

                    step(
                        n: 1,
                        title: "Provision a Linux VPS",
                        body: "8 vCPU / 32 GiB / 500 GiB NVMe is plenty. Hetzner CCX, Vultr HF, or any provider you trust."
                    )
                    step(
                        n: 2,
                        title: "Point DNS",
                        body: "Set `pitwall.<your-domain>` and `*.pitwall.<your-domain>` at the VPS public IP. Caddy will handle TLS automatically (Cloudflare DNS-01 wildcard)."
                    )
                    step(
                        n: 3,
                        title: "Create a Postgres database",
                        body: "On your Postgres server: `CREATE DATABASE pitwall; CREATE ROLE pitwall_app …;`  Enable `pgcrypto` and allow the VPS IP in `pg_hba.conf` over SSL."
                    )
                    step(
                        n: 4,
                        title: "Clone, configure, bootstrap",
                        body: "git clone github.com/shooter51/m1cr-pitwall  →  cd infra  →  cp .env.example .env  →  fill in PITWALL_DB_URL, generate PITWALL_CLIENT_KEY (openssl rand -base64 48), then ./scripts/bootstrap.sh"
                    )
                    step(
                        n: 5,
                        title: "Connect this app",
                        body: "Tap 'I have a backend' below and paste your Lobby URL + the client key you generated. You only do this once per device."
                    )

                    HStack {
                        Spacer()
                        Button {
                            showJoin = true
                        } label: {
                            Text("I have a backend — connect")
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(PW.guards)
                                .foregroundStyle(PW.silver)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 12)
                }
                .padding(24)
            }
            .background(PW.carbon)
            .navigationTitle("Create backend")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showJoin) {
                JoinBackendSheet().presentationDetents([.medium, .large])
            }
        }
    }

    private func step(n: Int, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold).monospaced())
                .frame(width: 24, height: 24)
                .background(PW.guards)
                .foregroundStyle(PW.silver)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(PW.silver)
                Text(body).font(.system(size: 12)).foregroundStyle(PW.silverMid)
            }
        }
    }
}
