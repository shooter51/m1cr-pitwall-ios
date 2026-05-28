import SwiftUI

struct RigCardView: View {
    let rig: LiveRig

    private var isP1: Bool { rig.position == 1 }
    private var isOccupied: Bool { rig.status == .occupied }
    private var isInPit: Bool { rig.pitStatus == .inPit }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                // Header row
                HStack(alignment: .center) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("RIG")
                            .font(PW.FontStyle.card(22))
                            .foregroundColor(PW.silver)
                            .tracking(-0.44)

                        Text(String(format: "%02d", rig.rigNumber))
                            .font(PW.FontStyle.card(26))
                            .foregroundColor(PW.guardsBright)
                            .tracking(-0.52)
                    }

                    Spacer()

                    StatusChip(chipStatus(rig.status), compact: true)
                }

                if isOccupied {
                    occupiedContent
                } else {
                    nonOccupiedContent
                }
            }
            .padding(14)
            .frame(minHeight: 138)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PW.panel)
            .overlay(
                Rectangle().stroke(isP1 ? PW.guards : PW.line, lineWidth: isP1 ? 1 : 1)
            )
            .overlay(alignment: .leading) {
                if isP1 {
                    Rectangle().fill(PW.guards).frame(width: 3)
                }
            }
            .opacity(rig.status == .offline ? 0.62 : 1)

            // In-pit flag
            if isInPit {
                Text("IN PIT")
                    .font(PW.FontStyle.mono(8, weight: .bold))
                    .foregroundColor(.black)
                    .tracking(1.8)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(PW.warn)
                    .padding([.top, .trailing], 8)
            }
        }
    }

    // MARK: Occupied content

    private var occupiedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Driver + booking ref
            HStack(alignment: .lastTextBaseline) {
                Text(rig.driverName ?? "—")
                    .font(PW.FontStyle.mono(10, weight: .semibold))
                    .foregroundColor(PW.silver)
                    .tracking(0.8)
                    .lineLimit(1)
                Spacer()
                if let ref = rig.bookingRef {
                    Text(ref)
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.8)
                }
            }

            // Lap times
            HStack(spacing: 8) {
                lapBlock(label: "BEST", ms: rig.bestLapMs, color: PW.ok)
                lapBlock(label: "LAST", ms: rig.lastLapMs, color: PW.silver2)
            }

            Spacer(minLength: 0)

            // Bottom: P-badge + lap + speed/gear
            HStack(alignment: .center) {
                if let pos = rig.position {
                    HStack(spacing: 6) {
                        Text("P\(pos)")
                            .font(PW.FontStyle.mono(11, weight: .bold))
                            .foregroundColor(pos == 1 ? .white : PW.silver)
                            .tracking(0.4)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(pos == 1 ? PW.guards : PW.panel3)

                        if let lap = rig.currentLap {
                            Text("LAP \(lap)")
                                .font(PW.FontStyle.mono(9, weight: .semibold))
                                .foregroundColor(PW.silverDim)
                                .tracking(1.8)
                        }
                    }
                }

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    if let speed = rig.speedKph {
                        Text("\(speed)")
                            .font(PW.FontStyle.mono(13, weight: .bold))
                            .foregroundColor(PW.silver)
                    }
                    if let gear = rig.gear {
                        Text("KM/H · G\(gear)")
                            .font(PW.FontStyle.mono(8, weight: .semibold))
                            .foregroundColor(PW.silverDim)
                            .tracking(2.0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func lapBlock(label: String, ms: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(PW.FontStyle.mono(8, weight: .semibold))
                .foregroundColor(PW.silverDim)
                .tracking(2.2)
            Text(formatLap(ms))
                .font(PW.FontStyle.mono(14, weight: .bold))
                .foregroundColor(color)
                .tracking(0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Non-occupied content

    @ViewBuilder
    private var nonOccupiedContent: some View {
        Spacer(minLength: 0)
        VStack(spacing: 6) {
            switch rig.status {
            case .available:
                Text("READY · PRESS QR")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)

                ZStack {
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundColor(PW.lineStrong)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(PW.silverDim)
                }

            case .maintenance:
                Text("PIT LANE")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.warn)
                    .tracking(2.2)

                if let note = rig.maintenanceNote {
                    Text(note)
                        .font(PW.FontStyle.body(11))
                        .foregroundColor(PW.silverMid)
                        .multilineTextAlignment(.center)
                }

            case .offline:
                Text("OFFLINE")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverDim)
                    .tracking(2.2)
                Text("NO HEARTBEAT")
                    .font(PW.FontStyle.mono(9, weight: .semibold))
                    .foregroundColor(PW.silverInk)
                    .tracking(1.8)

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        Spacer(minLength: 0)
    }

    // MARK: Helpers

    private func chipStatus(_ s: Rig.RigStatus) -> StatusChip.Status {
        switch s {
        case .available: return .available
        case .occupied: return .occupied
        case .maintenance: return .maintenance
        case .offline: return .offline
        }
    }

    private func formatLap(_ ms: Int?) -> String {
        LapTimeFormatter.format(ms)
    }
}

// MARK: - LiveRig convenience extensions

private extension LiveRig {
    var rigNumber: Int {
        // Extract trailing number from label like "Rig 01" or "rig-01"
        if let n = label.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init).first {
            return n
        }
        return 0
    }

    var bookingRef: String? {
        // currentSessionId used as booking ref placeholder
        currentSessionId
    }

    var maintenanceNote: String? { nil }
    var speedKph: Int? { nil }
    var gear: Int? { nil }
}
