import SwiftUI

struct MacroGrid: View {
    private static let rowHeight: CGFloat = 64

    let calories: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            value("Calories", calories, "cal")
            value("Protein", protein, "g")
            value("Carbs", carbohydrates, "g")
            value("Fat", fat, "g")
        }
        .overlay {
            Rectangle()
                .fill(AppPalette.divider)
                .frame(height: 1)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 20, alignment: .leading),
            GridItem(.flexible(), spacing: 20, alignment: .leading)
        ]
    }

    private func value(_ label: String, _ number: Double?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(AppTypography.eyebrow)
                .tracking(0.8)
                .foregroundStyle(AppPalette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(number?.formatted(.number.precision(.fractionLength(0...1))) ?? "—")
                    .font(AppTypography.metric)
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.ink)
                Text(unit).font(.subheadline).foregroundStyle(AppPalette.muted)
            }
        }
        .frame(height: Self.rowHeight, alignment: .topLeading)
    }
}

#Preview {
    MacroGrid(calories: 285, protein: 12.2, carbohydrates: 35.7, fat: 10.4)
        .appCard()
        .padding()
        .background(AppPalette.paper)
}
