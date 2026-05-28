import SwiftUI

/// Shown when no Backend is configured yet (first launch, or after the operator
/// removed all saved backends). Two big paths: join existing, or create new.
struct BackendPickerView: View {
    @Environment(BackendStore.self) private var store
    @Environment(MCClient.self) private var mc
    @State private var sheet: Sheet?

    enum Sheet: Identifiable {
        case join, create
        var id: Int { self == .join ? 0 : 1 }
    }

    var body: some View {
        ZStack {
            PW.carbon.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                header
                buttons
                Spacer()
                if !store.backends.isEmpty {
                    savedBackendsStrip
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .join:   JoinBackendSheet().presentationDetents([.medium, .large])
            case .create: CreateBackendSheet().presentationDetents([.large])
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(PW.guards).frame(width: 72, height: 72)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PW.silver)
            }
            Text("PitWall").font(.system(size: 36, weight: .bold)).foregroundStyle(PW.silver)
            Text("Connect to your venue's PitWall server.")
                .font(.system(size: 15))
                .foregroundStyle(PW.silverMid)
                .multilineTextAlignment(.center)
        }
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            bigButton(
                title: "Connect to a Server",
                subtitle: "Enter the server address and access key from your venue admin.",
                icon: "link",
                tint: PW.guards
            ) { sheet = .join }

            bigButton(
                title: "Set Up a New Server",
                subtitle: "Deploy your own PitWall server. We'll walk you through it.",
                icon: "plus.square",
                tint: PW.info
            ) { sheet = .create }
        }
    }

    private func bigButton(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(tint).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(PW.silver)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(PW.silver)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(PW.silverMid)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(PW.silverDim)
            }
            .padding(16)
            .background(PW.panel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PW.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var savedBackendsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved Servers")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(PW.silverDim)
            ForEach(store.backends) { backend in
                Button {
                    store.setCurrent(backend.id)
                    mc.switchBackend(backend)
                } label: {
                    HStack {
                        Image(systemName: "server.rack").foregroundStyle(PW.silverMid)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(backend.displayName).font(.system(size: 14, weight: .medium)).foregroundStyle(PW.silver)
                            Text(backend.lobbyURL.absoluteString).font(.system(size: 11).monospaced()).foregroundStyle(PW.silverDim)
                        }
                        Spacer()
                        if store.currentId == backend.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(PW.ok)
                        }
                    }
                    .padding(12)
                    .background(PW.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
