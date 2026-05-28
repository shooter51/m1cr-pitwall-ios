import SwiftUI

/// 60pt app-header bar. 3-column grid: eyebrow+title left, center info, right actions.
struct PWTopBar<Center: View, Actions: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var center: Center
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 0) {
            // Left — eyebrow + title
            VStack(alignment: .leading, spacing: 2) {
                Text("// \(eyebrow)")
                    .pwEyebrow()
                Text(title.uppercased())
                    .font(PW.FontStyle.title(30))
                    .foregroundColor(PW.silver)
                    .tracking(-0.6)
                    .lineLimit(1)
            }
            .padding(.leading, 22)
            .frame(minWidth: 0, alignment: .leading)

            // Center — info breadcrumb
            HStack(spacing: 18) {
                center
            }
            .font(PW.FontStyle.mono(10, weight: .semibold))
            .foregroundColor(PW.silverMid)
            .tracking(1.6)
            .frame(maxWidth: .infinity)

            // Right — action buttons
            HStack(spacing: 10) {
                actions
            }
            .padding(.trailing, 22)
            .frame(minWidth: 0, alignment: .trailing)
        }
        .frame(height: PW.topbarHeight)
        .background(PW.carbon)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PW.line).frame(height: 1)
        }
    }
}

/// Vertical divider for use inside top bar center info
struct PWTopBarDivider: View {
    var body: some View {
        Rectangle()
            .fill(PW.line)
            .frame(width: 1, height: 14)
    }
}
