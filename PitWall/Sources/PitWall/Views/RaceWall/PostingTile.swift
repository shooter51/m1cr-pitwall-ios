import SwiftUI

struct PostingTile: View {
    let posting: RacePosting
    let onJoin: () -> Void
    let onSpectate: () -> Void
    let onPushToDisplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            trackLine
            HStack(spacing: 8) {
                statusPill
                slotPill
                Spacer()
                actionButton
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PW.panel2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(posting.status == .live ? PW.guards : PW.line, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(posting.trackName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PW.silver)
                if let src = posting.sourceName {
                    Text("from \(src)")
                        .font(.system(size: 11))
                        .foregroundStyle(PW.silverDim)
                }
            }
            Spacer()
            if posting.status == .live {
                LivePulse()
            }
        }
    }

    private var trackLine: some View {
        HStack(spacing: 12) {
            Label(posting.vehicleClass, systemImage: "car.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PW.silverMid)
            if let v = posting.vehicleName {
                Text("· \(v)")
                    .font(.system(size: 12)).foregroundStyle(PW.silverDim)
            }
        }
    }

    private var statusPill: some View {
        Text(posting.status.rawValue.uppercased())
            .font(.system(size: 10, weight: .semibold).monospaced())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(statusColor.opacity(0.18))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var slotPill: some View {
        Text("\(posting.slotOpen)/\(posting.slotTotal) slots")
            .font(.system(size: 10, weight: .semibold).monospaced())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(PW.panel3)
            .foregroundStyle(PW.silver)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch posting.status {
        case .live: return PW.ok
        case .full: return PW.warn
        case .ended, .cancelled: return PW.silverDim
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if posting.slotOpen > 0 && posting.status == .live {
            Button("JOIN") { onJoin() }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(PW.guards)
                .foregroundStyle(PW.silver)
                .clipShape(Capsule())
                .buttonStyle(.plain)
        } else {
            Menu {
                Button("Spectate", action: onSpectate)
                Button("Push to Display", action: onPushToDisplay)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(PW.silverMid)
            }
        }
    }
}

private struct LivePulse: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(PW.guards)
            .frame(width: 8, height: 8)
            .opacity(on ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
