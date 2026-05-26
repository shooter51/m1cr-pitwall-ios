import SwiftUI

struct KPITile: View {
    let label: String
    let value: String
    var accent: Color = PW.silver

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(PW.silverDim)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
    }
}
