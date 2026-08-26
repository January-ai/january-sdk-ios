import SwiftUI

struct NutritionList: View {
    let rows: [NutrientRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LabeledContent(row.name, value: "\(row.value.formatted(.number.precision(.fractionLength(0...2)))) \(row.unit)")
                    .monospacedDigit()
                    .padding(.vertical, 10)
                if index < rows.count - 1 { Divider() }
            }
        }
    }
}

#Preview {
    NutritionList(rows: [
        NutrientRow(name: "Fiber", value: 3.5, unit: "g"),
        NutrientRow(name: "Sodium", value: 410, unit: "mg")
    ])
    .appCard()
    .padding()
    .background(AppPalette.paper)
}

