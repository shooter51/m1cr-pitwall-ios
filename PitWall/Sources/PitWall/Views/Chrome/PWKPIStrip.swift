import SwiftUI

/// A single KPI tile — 3px colored left bar + mono label + 22px value + optional aux.
struct PWKPITile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var aux: String? = nil
    var accentColor: Color = PW.guards
    var valueColor: Color = PW.silver

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(2.0)

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(value)
                            .font(PW.FontStyle.telemetry(22))
                            .foregroundColor(valueColor)
                            .tracking(0)

                        if let unit {
                            Text(unit)
                                .font(PW.FontStyle.mono(11, weight: .medium))
                                .foregroundColor(PW.silverDim)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let aux {
                    Text(aux.uppercased())
                        .font(PW.FontStyle.mono(9, weight: .semibold))
                        .foregroundColor(PW.silverDim)
                        .tracking(1.8)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }
}

/// Flat row of equal-width KPI tiles.
struct PWKPIStrip: View {
    struct Item {
        let label: String
        let value: String
        var unit: String? = nil
        var aux: String? = nil
        var accent: Color = PW.guards
        var color: Color = PW.silver
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                PWKPITile(
                    label: item.label,
                    value: item.value,
                    unit: item.unit,
                    aux: item.aux,
                    accentColor: item.accent,
                    valueColor: item.color
                )
                .frame(maxWidth: .infinity)

                if idx < items.count - 1 {
                    Rectangle().fill(PW.line).frame(width: 1)
                }
            }
        }
        .background(PW.carbon2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }
}
