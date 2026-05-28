import SwiftUI

struct RigCardView: View {
    let rig: LiveRig

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rig.label.uppercased())
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(PW.silver)
                    Text(rig.orgId)
                        .font(.system(size: 10))
                        .foregroundStyle(PW.silverDim)
                }
                Spacer()
                ChipView(status: rig.status)
            }
            .padding(.horizontal, PW.cardPadding)
            .padding(.vertical, 12)

            Divider()
                .background(PW.line)

            // Telemetry body
            VStack(alignment: .leading, spacing: 8) {
                if let driver = rig.driverName {
                    HStack {
                        Text("DRIVER")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PW.silverDim)
                        Spacer()
                        Text(driver.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(PW.silver)
                            .lineLimit(1)
                    }
                }

                if let bestLap = rig.bestLapMs {
                    lapRow(label: "BEST", ms: bestLap, highlight: true)
                }

                if let lastLap = rig.lastLapMs {
                    lapRow(label: "LAST", ms: lastLap, highlight: false)
                }

                HStack {
                    if let position = rig.position {
                        positionBadge(position)
                    }
                    Spacer()
                    if let lap = rig.currentLap {
                        Text("LAP \(lap)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PW.silverDim)
                    }
                    if let pit = rig.pitStatus, pit != .onTrack {
                        Text(pit.rawValue.uppercased().replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(PW.warn)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PW.warn.opacity(0.15))
                    }
                }
            }
            .padding(.horizontal, PW.cardPadding)
            .padding(.vertical, 10)
        }
        .background(PW.panel)
        .overlay(alignment: .leading) {
            if rig.position == 1 {
                Rectangle()
                    .fill(PW.guards)
                    .frame(width: 3)
            }
        }
    }

    // MARK: - Sub-views

    private func lapRow(label: String, ms: Int, highlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Spacer()
            Text(formatLap(ms))
                .font(.system(size: 13, weight: highlight ? .bold : .regular, design: .monospaced))
                .foregroundStyle(highlight ? PW.ok : PW.silver)
        }
    }

    private func positionBadge(_ pos: Int) -> some View {
        Text("P\(pos)")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(pos == 1 ? PW.guards : PW.silverMid)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pos == 1 ? PW.guards.opacity(0.15) : PW.panel2)
    }

    private func formatLap(_ ms: Int) -> String {
        LapTimeFormatter.format(ms)
    }
}
