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
                        Text("Set Up a New Server")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(PW.silver)
                        Text("PitWall runs on a server that your IT team sets up. Follow these steps to get started.")
                            .font(.system(size: 13))
                            .foregroundStyle(PW.silverMid)
                    }

                    step(
                        n: 1,
                        title: "Get a server",
                        body: "Your IT team needs a Linux server (cloud or on-premises)."
                    )
                    step(
                        n: 2,
                        title: "Set up a web address",
                        body: "Point a domain name at the server."
                    )
                    step(
                        n: 3,
                        title: "Set up the database",
                        body: "Install and configure the database."
                    )
                    step(
                        n: 4,
                        title: "Install PitWall",
                        body: "Run the PitWall installer on the server."
                    )
                    step(
                        n: 5,
                        title: "Connect this iPad",
                        body: "Use the server address and access key from step 4."
                    )

                    Text("Server setup requires technical knowledge. Contact your IT team or PitWall support for help.")
                        .font(.system(size: 12))
                        .foregroundStyle(PW.silverMid)
                        .padding(12)
                        .background(PW.panel2)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PW.line, lineWidth: 1))

                    HStack {
                        Spacer()
                        Button {
                            showJoin = true
                        } label: {
                            Text("I have a server — connect")
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
            .navigationTitle("Set Up a New Server")
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
