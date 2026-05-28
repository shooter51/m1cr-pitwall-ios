import SwiftUI

struct PostingTile: View {
    let posting: RacePosting
    let onJoin: () -> Void

    private var isLive: Bool { posting.status == .live }
    private var isEnded: Bool { posting.status == .ended || posting.status == .cancelled }
    private var isFull: Bool { posting.status == .full }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let src = posting.sourceName {
                            Text("FROM · \(src.uppercased())")
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.silverDim)
                                .tracking(2.0)
                        }
                        Text(posting.trackName.uppercased())
                            .font(PW.FontStyle.card(26))
                            .foregroundColor(PW.silver)
                            .tracking(-0.52)
                            .lineLimit(1)
                        Text(posting.vehicleClass.uppercased())
                            .font(PW.FontStyle.mono(10, weight: .semibold))
                            .foregroundColor(PW.silver2)
                            .tracking(1.0)
                    }
                    Spacer()
                    StatusChip(chipStatus(posting.status), compact: true)
                }

                // Slot grid
                HStack(spacing: 8) {
                    let filled = posting.slotTotal - posting.slotOpen
                    ForEach(0..<min(posting.slotTotal, 12), id: \.self) { idx in
                        Rectangle()
                            .fill(idx < filled ? (isLive ? PW.guards : PW.silverMid) : Color.clear)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Rectangle().stroke(
                                    idx < filled ? (isLive ? PW.guards : PW.silverMid) : PW.lineStrong,
                                    lineWidth: 1
                                )
                            )
                    }
                    Text("\(filled) / \(posting.slotTotal) GRID")
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverMid)
                        .tracking(1.8)
                        .padding(.leading, 4)
                }

                // Footer
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEADER · —")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(1.8)
                        Text("—:——.———")
                            .font(PW.FontStyle.mono(12, weight: .bold))
                            .foregroundColor(isEnded ? PW.silverMid : PW.ok)
                    }

                    Spacer()

                    if isLive {
                        Button("JOIN →") { onJoin() }
                            .buttonStyle(PrimaryButtonStyle(.primary, compact: true))
                    } else if isFull {
                        Button("RSVP") {}
                            .buttonStyle(PrimaryButtonStyle(.secondary, compact: true))
                    } else if isEnded {
                        Text("WINNER · —")
                            .font(PW.FontStyle.mono(9, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(2.0)
                    }
                }
                .padding(.top, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(PW.line).frame(height: 1)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PW.panel)
            .overlay(
                Rectangle().stroke(isLive ? PW.guards : PW.line, lineWidth: isLive ? 1 : 1)
            )
            .overlay(alignment: .leading) {
                if isLive {
                    Rectangle().fill(PW.guards).frame(width: 3)
                }
            }

            // Corner stripes for live
            if isLive {
                CornerStripes(size: 64)
                    .offset(x: 16, y: -16)
                    .allowsHitTesting(false)
            }
        }
    }

    private func chipStatus(_ s: RacePosting.Status) -> StatusChip.Status {
        switch s {
        case .live: return .live
        case .full: return .full
        case .ended, .cancelled: return .ended
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
